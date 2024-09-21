# Usage: `glob.bash [subcommand] [patterns...]` (Pass files over stdin, nul-delimited)

set -o errexit
set -o nounset
set -o pipefail

function main {
  parse_arguments "$@"
  "$subcommand"
}

function has_match {
  readarray -d '' matches < <(filter)

  if [ ${#matches[@]} -gt 0 ]; then
    return 0
  else
    return 1
  fi
}

function filter {
  readarray -d '' path_predicates < <(make_path_predicates)
  # shellcheck disable=2185
  find -files0-from - "${path_predicates[@]}" -print0 2>/dev/null
}

function make_path_predicates {
  flags=()
  for pattern in "${patterns[@]}"; do
    flags=("${flags[@]}" '-path' "$pattern" '-o')
  done
  # remove extra '-o'
  unset 'flags[-1]'

  if [ -n "$invert" ]; then
    print_with_nul \! \( "${flags[@]}" \)
  else
    print_with_nul \( "${flags[@]}" \)
  fi
}

function parse_arguments {
  subcommand="$1"
  set -- "${@:2}"

  invert=
  if [ "${1:-}" = '--invert' ]; then
    invert=1
    set -- "${@:2}"
  fi

  patterns=("$@")
  if [ ${#patterns[@]} -eq 0 ]; then
    if [ -n "$invert" ]; then
      patterns=('')
    else
      patterns=('*')
    fi
  fi
}

function print_with_nul {
  printf '%s\0' "$@"
}

main "$@"
