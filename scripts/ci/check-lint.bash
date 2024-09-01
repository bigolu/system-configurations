set -o errexit
set -o nounset
set -o pipefail

if [ "$1" = 'pr' ]; then
  reporter='-reporter=github-pr-review'
elif [ "$1" = 'commit' ]; then
  reporter='-reporter=github-check'
else
  echo 'Error: reporter type not specified' 1>&2
  exit 1
fi

reviewdog() {
  command reviewdog -fail-level=any -filter-mode=nofilter "$reporter" "$@"
}

found_problem=
run_linter() {
  "$@" || found_problem=1
}

run_linter just lint --linters taplo_logic
run_linter just lint --linters taplo_style

if [ "$found_problem" = '1' ]; then
  exit 1
fi
