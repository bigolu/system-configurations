#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter gitMinimal]"
#MISE hide=true
#MISE dir="{{cwd}}"

# This script runs the given fix command and behaves according to the specified
# `FIX_MODE`. It's used for running the jobs in the "fix" group in lefthook.
#
# Usage: <this_script> [fix_command]...
#
# Environment Variables
#   FIX_MODE (required):
#     Determines how this script should behave after running the fix. Options:
#       - DEVELOPMENT
#       - CI_CHECK_PULL_REQUEST
#       - CI_FIX_PULL_REQUEST

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

function main {
  local -ra fix_command=("$@")

  diff_before_running_fix="$(diff_including_untracked)"
  "${fix_command[@]}"
  diff_after_running_fix="$(diff_including_untracked)"

  # If no files changed, then nothing was fixed.
  if [[ $diff_before_running_fix == "$diff_after_running_fix" ]]; then
    return
  fi

  case "${FIX_MODE:?}" in
    'DEVELOPMENT')
      # - This failure lets me know which fix commands actually fixed anything since
      #   lefthook will highlight failed commands differently.
      # - This failure will cause the pre-commit hook to abort so I can see what
      #   fixes were made and, if everything looks good, include them in the commit.
      exit 1
      ;;
    'CI_CHECK_PULL_REQUEST')
      # Print the diff so people can see it in the CI console.
      diff_including_untracked

      # Remove the changes to keep the git repository in a clean state for the next fix
      # command that runs. The repo needs to be in a clean state so the diff printed
      # only contains changes made by the current fix command. I could drop the stash
      # as well, but in the event that this code is run locally, to debug for example,
      # I don't want to permanently delete anyone's changes.
      git stash --include-untracked 1>/dev/null

      # Why it should fail:
      # - This failure lets me know which fix commands actually fixed anything since
      #   lefthook will highlight failed commands differently.
      # - This failure will make lefthook fail which will cause the overall CI check
      #   to fail.
      exit 1
      ;;
    'CI_FIX_PULL_REQUEST')
      # There's nothing to do in this case
      ;;
    *)
      echo "Error, invalid FIX_MODE: $FIX_MODE" >&2
      exit 1
      ;;
  esac
}

# I include untracked files in case a fix command creates new files, like a code
# generation fix for example.
function diff_including_untracked {
  git ls-files -z --others --exclude-standard |
    {
      readarray -d '' initially_untracked_files
      track "${initially_untracked_files[@]}"

      # Why I can't use a pager:
      #   - This may be run non-interactively like in CI or through a git GUI for
      #     example.
      #   - If a pager was used, the next fix command would not be able to run until
      #     the pager was closed.
      git --no-pager diff --color

      untrack "${initially_untracked_files[@]}"
    }
}

function track {
  local -ra files=("$@")

  if ((${#files[@]} > 0)); then
    git add --intent-to-add -- "${files[@]}"
  fi
}

function untrack {
  local -ra files=("$@")

  if ((${#files[@]} > 0)); then
    git reset --quiet -- "${files[@]}"
  fi
}

main "$@"
