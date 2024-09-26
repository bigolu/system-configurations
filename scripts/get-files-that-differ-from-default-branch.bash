set -o errexit
set -o nounset
set -o pipefail

remote="${1:-origin}"

# source: https://stackoverflow.com/a/50056710
default_branch_name="$(LC_ALL=C git remote show "$remote" | sed -n '/HEAD branch/s/.*: //p')"

git diff -z --diff-filter=d --name-only "$remote/$default_branch_name" HEAD

# Untracked files
git ls-files -z --others --exclude-standard
