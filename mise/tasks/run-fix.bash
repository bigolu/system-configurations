#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter git]"
#MISE hide=true
#MISE dir="{{cwd}}"

# This script runs the given fix command and allows you to specify certain actions to
# take after running the fix. A fix is anything that modifies the source code to
# correct an issue. This includes things like formatters, code generators, and lint
# fixers.
#
# Usage: run-fix [fix_command]...
#
# Example: run-fix prettier --write some-file.js
#
# Environment Variables:
#   RUN_FIX_ACTIONS (optional):
#     A list of comma-separated actions to take after running the fix. This is only
#     used if the fix actually fixes anything, which is determined by checking for
#     changed files after running it. Actions:
#       diff:
#         Print the current git diff. This can be used in CI to see the exact changes
#         made.
#       stage:
#         Stage any changes in the git repository. This is useful during development
#         if you want to automatically include any fixes in your commit.
#       stash:
#         Stash any changes in the git repository. This is useful in CI if you also
#         use the `diff` action and run multiple fix commands after each other. This
#         way, the diff printed will only contain the changes for the current fix
#         command and not the ones run previously. To avoid the permanent loss of
#         changes, the stash is not dropped.
#       fail:
#         Exit with exit code 1. This is useful for causing a check to fail in CI.
#         It's also useful during development for causing a git hook to fail like
#         pre-commit. It can also be used to be able to detect which fix commands
#         actually fixed anything.

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

function main {
  local -ra fix_command=("$@")

  diff_before_fix="$(diff_including_untracked)"
  "${fix_command[@]}"
  diff_after_fix="$(diff_including_untracked)"

  if
    # No files changed
    [[ $diff_before_fix == "$diff_after_fix" ]] ||
      [[ -z ${RUN_FIX_ACTIONS:-} ]]
  then
    return
  fi

  local actions
  # It's easier to split a newline-delimited string than a comma-delimited one since
  # herestring (<<<) adds a newline to the end of the string.
  readarray -t actions <<<"${RUN_FIX_ACTIONS//,/$'\n'}"

  for action in "${actions[@]}"; do
    case "$action" in
      'diff')
        diff_including_untracked
        ;;
      'stage')
        git add --all
        ;;
      'stash')
        git stash --include-untracked --quiet
        ;;
      'fail')
        exit 1
        ;;
      *)
        echo "run-fix: Error, invalid action: $action" >&2
        exit 2
        ;;
    esac
  done
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
