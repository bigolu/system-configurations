set -o errexit
set -o nounset
set -o pipefail

function main {
  found_problem=

  if [ $# -gt 0 ]; then
    files=("$@")
  else
    readarray -d '' files < <(get_files)
  fi

  if [ "${#files[@]}" -eq 0 ]; then
    echo 'No files differ from the default branch, exiting.'
    exit
  fi

  print_with_nul "${files[@]}" |
    lefthook run --files-from-stdin generate || found_problem=1

  print_with_nul "${files[@]}" |
    lefthook run --files-from-stdin fix-lint || found_problem=1

  # Print a header for consistency with lefthook
  reset='[m'
  accent='[36m'
  printf '\n\e%s┃ Format ❯\e%s\n' "$accent" "$reset"
  # treefmt keeps a cache to tell whether a file has changed since it last ran
  # so no need to pass in changed files.
  #
  # Use chronic so there's no output if it succeeds, like lefthook.
  #
  # Run formatting after lint fixes because sometimes a lint fix produces code
  # that doesn't comply with the formatting.
  chronic treefmt --on-unmatched=fatal --fail-on-change || found_problem=1

  print_with_nul "${files[@]}" |
    lefthook run --files-from-stdin check-lint || found_problem=1

  if [ "$found_problem" = 1 ]; then
    exit 1
  else
    exit 0
  fi
}

function get_default_branch {
  # TODO: This may not be the remote that the code will eventually be pushed to.
  remote='origin'

  # source: https://stackoverflow.com/a/50056710
  default_branch_name="$(LC_ALL=C git remote show "$remote" | sed -n '/HEAD branch/s/.*: //p')"

  echo "$remote/$default_branch_name"
}

function get_files {
  all_files=()

  # Since we assume everything on the default branch is correct, lets get all
  # modified files between the HEAD of the default branch and the HEAD of the
  # current branch , included staged and unstaged changes.
  readarray -d '' tmp < <(git diff -z --diff-filter=d --name-only "$(get_default_branch)")
  all_files=("${all_files[@]}" "${tmp[@]}")

  # Add in untracked files as well
  readarray -d '' tmp < <(git ls-files -z --others --exclude-standard)
  all_files=("${all_files[@]}" "${tmp[@]}")

  print_with_nul "${all_files[@]}"
}

function print_with_nul {
  for ((i = 1; i <= $#; i++)); do
    printf '%s' "${!i}"
    if [ $i -ne $# ]; then
      printf '\0'
    fi
  done
}

main "$@"
