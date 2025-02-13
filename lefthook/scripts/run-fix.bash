#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter]"

# Usage: {this script} [fix_command]...
#
# This script runs the given fix command and reports any fixed problems appropriately
# depending on whether it's run locally or in CI. This should be used for running
# fixes in lefthook. A fix is any check that modifies files like a formatter or code
# generator.

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

function main {
  diff_before_running_fix="$(diff_including_untracked)"
  "$@"
  diff_after_running_fix="$(diff_including_untracked)"

  # If no files changed then nothing was fixed
  if [[ $diff_before_running_fix == "$diff_after_running_fix" ]]; then
    return
  fi

  if [[ ${CI:-} == 'true' ]]; then
    # Print the diff so people can see it in the CI console
    diff_including_untracked

    # Remove the changes to keep the git repository in a clean state for the next fix
    # command that runs. The repo needs to be in a clean state so the diff printed
    # only contains changes made by the current fix command. I could drop the stash
    # as well, but in the event that this code is run locally, to debug for example,
    # I don't want to permanently delete anyone's changes.
    git stash --include-untracked 1>/dev/null
  fi

  # Why it should fail in CI:
  #   - This failure will make lefthook fail which will cause the overall CI check
  #     to fail.
  #
  # Why it should fail locally:
  #   - This failure will cause the pre-commit hook to abort the push so I can fix
  #     up my commits.
  #   - The failures let me know which fix commands actually fixed anything since
  #     lefthook will highlight failed commands differently.
  exit 1
}

# I include untracked files in case a fix command creates new files, like a code
# generation fix for example.
function diff_including_untracked {
  git ls-files -z --others --exclude-standard |
    {
      readarray -d '' untracked_files
      track_files "${untracked_files[@]}"
      # Why I can't use a pager:
      #   - This may be run non-interactively like in CI or through a git GUI for
      #     example.
      #   - If a pager was used, the next fix command would not be able to run until
      #     the pager was closed.
      git --no-pager diff --color
      untrack_files "${untracked_files[@]}"
    }
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
