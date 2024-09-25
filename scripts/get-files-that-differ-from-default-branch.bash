set -o errexit
set -o nounset
set -o pipefail

remote="${1:-origin}"

default_branch_name="$(LC_ALL=C git remote show "$remote" | sed -n '/HEAD branch/s/.*: //p')"
git diff -z --diff-filter=d --name-only HEAD "$remote/$default_branch_name"
