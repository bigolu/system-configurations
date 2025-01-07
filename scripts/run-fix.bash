#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter gitMinimal]"

# Usage:
#
# [this_script] [fix_command]...
#
# This script runs the given fix command and reports any fixed problems appropriately
# depending on whether it's run locally or in CI. This is used in lefthook to run any
# fix. A fix is any check that modifies files like a formatter or code generator.

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

function main {
  local -ra fix_command=("$@")

  if did_fix "${fix_command[@]}"; then
    if [[ ${CI:-} == 'true' ]]; then
      # Print the diff so people can see it in the CI console
      diff_including_untracked

      # Remove the changes to keep the git repository in a clean state for the next
      # fix command that runs. I could drop the stash as well, but in the event that
      # this code accidentally runs when the script is run locally, I don't want to
      # permanently delete anyone's changes.
      git stash --include-untracked 1>/dev/null

      # I'm failing here to make lefthook fail which will cause the overall CI check
      # to fail.
      exit 1
    else
      # Why I'm failing here:
      #   - This failure will cause the pre-push hook to abort the push so I can fix
      #     up my commits.
      #   - When I run all the fix commands together, the failures let me know which
      #     fix commands actually fixed anything since lefthook will highlight failed
      #     commands differently.
      exit 1
    fi
  fi
}

function did_fix {
  local -ra fix_command=("$@")

  local -r diff_before_running_fix="$(diff_including_untracked)"
  "${fix_command[@]}"
  local -r diff_after_running_fix="$(diff_including_untracked)"

  [[ $diff_before_running_fix != "$diff_after_running_fix" ]]
}

# I include untracked files in case a fix command creates new files, like a code
# generation fix for example.
function diff_including_untracked {
  local -a untracked_files
  readarray -d '' untracked_files < <(git ls-files -z --others --exclude-standard)

  track_files "${untracked_files[@]}"
  # This gets called in CI so I can't use a pager
  git --no-pager diff --color
  untrack_files "${untracked_files[@]}"
}

function track_files {
  local -ra files=("$@")

  if ((${#files[@]} > 0)); then
    git add --intent-to-add -- "${files[@]}"
  fi
}

function untrack_files {
  local -ra files=("$@")

  if ((${#files[@]} > 0)); then
    git reset --quiet -- "${files[@]}"
  fi
}

main "$@"
