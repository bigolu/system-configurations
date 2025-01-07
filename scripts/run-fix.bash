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
# fixers. A fixer is any check that modifies files like a formatter or code
# generator.

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

function main {
  fix_command=("$@")

  if [[ ${CI:-} == 'true' ]]; then
    "${fix_command[@]}"

    if has_uncommitted_changes; then
      # Print the diff so users can see it in the CI console
      diff_including_untracked

      # Remove the changes to keep the git repository in a clean state for the next
      # fix command that runs. I could drop the stash as well, but in the event that
      # this code accidentally runs when the script is run locally, I don't want to
      # permanently delete anyone's changes.
      git stash --include-untracked 1>/dev/null

      # I'm failing here to make lefthook fail which will cause the overall CI check
      # to fail.
      exit 1
    fi
  else
    # When running locally, I want this script to fail if any fixes were made:
    #   - This failure will cause the pre-push hook to abort the push so I can fix up
    #     my commits.
    #   - When I run all the fix commands together, the failures let me know _which_
    #     fix commands actually fixed anything since lefthook will highlight failed
    #     commands differently.
    if did_change_files "${fix_command[@]}"; then
      exit 1
    fi
  fi
}

function has_uncommitted_changes {
  [[ -n "$(git status --porcelain)" ]]
}

function did_change_files {
  diff_before_running="$(diff_including_untracked)"
  "$@"
  diff_after_running="$(diff_including_untracked)"

  [[ $diff_before_running != "$diff_after_running" ]]
}

function diff_including_untracked {
  readarray -d '' untracked_files < <(git ls-files -z --others --exclude-standard)
  track_files "${untracked_files[@]}"
  # This gets called in CI so I can't use a pager
  git --no-pager diff --color
  untrack_files "${untracked_files[@]}"
}

function track_files {
  if (($# > 0)); then
    git add --intent-to-add -- "$@"
  fi
}

function untrack_files {
  if (($# > 0)); then
    git reset --quiet -- "$@"
  fi
}

main "$@"
