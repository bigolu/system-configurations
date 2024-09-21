set -o errexit
set -o nounset
set -o pipefail

reporter=
if [ "${GITHUB_ACTIONS:-}" = 'true' ]; then
  reporter='-reporter=github-pr-review'
else
  reporter='-reporter=local'
fi

reviewdog \
  "$reporter" \
  -filter-mode=nofilter \
  -fail-on-error \
  -level=error "$@"
