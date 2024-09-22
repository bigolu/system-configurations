set -o errexit
set -o nounset
set -o pipefail

function main {
  found_problem=
  readarray -d '' files < <(get_files)

  if [ "${#files[@]}" -eq 0 ]; then
    echo 'No files differ from the default branch, exiting.'
    exit
  fi

  # Code generators
  bash scripts/qa/qa.bash generate "${files[@]}" || found_problem=1

  bash scripts/qa/qa.bash lint fix "${files[@]}" || found_problem=1

  # treefmt keeps a cache to tell whether a file has changed since it last ran
  # so no need to pass in changed files.
  #
  # Run formatting after lint fixes because sometimes a lint fix produces code
  # that doesn't comply with the formatting.
  bash scripts/treefmt.bash || found_problem=1

  bash scripts/qa/qa.bash lint check "${files[@]}" || found_problem=1

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

function get_files {
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
