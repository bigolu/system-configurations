set -o errexit
set -o nounset
set -o pipefail

remote="${1:-origin}"
git diff-tree -z -r --diff-filter=d --name-only --no-commit-id "$remote/HEAD" HEAD
# Untracked files
git ls-files -z --others --exclude-standard
