set -o errexit
set -o nounset
set -o pipefail

function main {
  groups="$1"
  files="$2"

  lefthook_command=(lefthook run check)
  if [ "$groups" != 'all' ]; then
    lefthook_command=("${lefthook_command[@]}" --commands "$groups")
  fi

  if [ "$files" = 'all' ]; then
    "${lefthook_command[@]}" --all-files
  elif [ "$files" = 'diff-from-default' ]; then
    get_files_that_differ_from_default_branch |
      "${lefthook_command[@]}" --files-from-stdin
  else
    echo "Error: invalid file set '$files'" >&2
    exit 1
  fi
}

function get_files_that_differ_from_default_branch {
  remote="${GIT_REMOTE:-origin}"
  git diff -z --diff-filter=d --name-only "$remote/HEAD"
  # Untracked files
  git ls-files -z --others --exclude-standard
}

main "$@"
