set -o errexit
set -o nounset
set -o pipefail

function main {
  warn_if_outside_github_actions

  diff_file="$(write_diff_to_file)"
  delete_changes

  bash scripts/reviewdog.bash -name="$1" -f=diff <"$diff_file"
}

function delete_changes {
  git stash --include-untracked
  git stash drop || true
}

function write_diff_to_file {
  diff_file="$(mktemp)"
  git diff >"$diff_file"
  echo "$diff_file"
}

function warn_if_outside_github_actions {
  reset='\e[m'
  yellow_fg_reversed='\e[1m\e[7m\e[33m'
  warning_badge="$yellow_fg_reversed WARNING $reset"

  if ! is_running_in_github_actions && [ "${FORCE:-}" != '1' ]; then
    echo -e "$warning_badge This script will delete any uncommitted changes in the repository. If you are ok with this, set the environment variable 'FORCE' to '1' and run the script again. For example: 'FORCE=1 bash $0'. To be safer, you can push all local changes to the remote to ensure you don't lose anything." 1>&2
    exit
  fi
}

function is_running_in_github_actions {
  if [ "${GITHUB_ACTIONS:-}" = 'true' ]; then
    return 0
  else
    return 1
  fi
}

main "$@"
