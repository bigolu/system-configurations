set -o errexit
set -o nounset
set -o pipefail

function main {
  found_problem=

  # Code generators
  files | bash scripts/qa/qa.bash generate || found_problem=1

  # treefmt keeps a cache to tell whether a file has changed since it last ran so
  # no need to pass in changed files.
  bash scripts/treefmt-wrapper.bash || found_problem=1

  files | bash scripts/qa/qa.bash lint fix || found_problem=1

  files | bash scripts/qa/qa.bash lint check || found_problem=1

  if [ "$found_problem" = 1 ]; then
    exit 1
  else
    exit 0
  fi
}

function get_default_branch {
  # TODO: This may not be the remote being pushed to
  remote='origin'

  # source: https://stackoverflow.com/a/50056710
  default_branch_name="$(LC_ALL=C git remote show "$remote" | sed -n '/HEAD branch/s/.*: //p')"

  echo "$remote/$default_branch_name"
}

function files {
  if [ "${PRE_PUSH_HOOK:-}" = 1 ]; then
    # Since we assume everything on the default branch is correct, lets get all
    # commmits between the HEAD of the default branch and the HEAD of the
    # current branch.
    git diff -z --diff-filter=d --name-only HEAD "$(get_default_branch)"
  else
    # Since we assume everything on the default branch is correct, lets get all
    # modified files between the HEAD of the default branch and the HEAD of the
    # current branch, including untracked files.
    git diff -z --diff-filter=d --name-only "$(get_default_branch)"
    printf '\0'
    git ls-files -z --others --exclude-standard
  fi
}

main
