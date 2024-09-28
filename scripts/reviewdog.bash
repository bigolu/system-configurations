set -o errexit
set -o nounset
set -o pipefail

reporter=
# This variable is set by the GitHub CI runner:
# https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/store-information-in-variables#default-environment-variables
if [ "${GITHUB_ACTIONS:-}" = 'true' ]; then
  reporter='-reporter=github-pr-review'
else
  reporter='-reporter=local'
fi

reviewdog \
  "$reporter" \
  -filter-mode=nofilter \
  -fail-level=any \
  -level=error "$@"
