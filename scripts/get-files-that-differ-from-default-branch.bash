set -o errexit
set -o nounset
set -o pipefail

remote="${1:-origin}"
git diff -z --diff-filter=d --name-only "$remote/HEAD"
# Untracked files
git ls-files -z --others --exclude-standard
