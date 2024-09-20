set -o errexit
set -o nounset
set -o pipefail

function main {
  # TODO: This may not be the remote being pushed to
  remote='origin'

  # source: https://stackoverflow.com/a/50056710
  default_branch_name="$(LC_ALL=C git remote show "$remote" | sed -n '/HEAD branch/s/.*: //p')"
  default_branch="$remote/$default_branch_name"

  found_problem=

  # Code generators
  changed_or_untracked_files |
    bash scripts/code-generation/generate.bash || found_problem=1

  printf '\nRunning fixers...\n%s' "$(printf '=%.0s' {1..40})"
  # treefmt keeps a cache to tell whether a file has changed since it last ran so
  # no need to pass in changed files.
  bash scripts/treefmt-wrapper.bash || found_problem=1

  changed_or_untracked_files | bash scripts/lint/lint.bash || found_problem=1

  # DEBUG:
  exit 1

  if [ -n "$found_problem" ]; then
    exit 1
  else
    exit 0
  fi
}

function changed_or_untracked_files {
  git diff -z --diff-filter=d --name-only "$default_branch"
  printf '\0'
  git ls-files -z --others --exclude-standard
}

main
