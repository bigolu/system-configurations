set -o errexit
set -o nounset
set -o pipefail

reset='\e[m'
blue_fg_reversed='\e[1m\e[7m\e[34m'
badge="$blue_fg_reversed INFO $reset"

function print_hint {
  if [ -n "${DIFF:-}" ]; then
    echo -e "$badge" "$1"
    set -- "${@:2}"

    git diff --color ORIG_HEAD HEAD -- "$@"
  else
    echo -e "$badge" "$@"
  fi
}

print_hint "$@"
