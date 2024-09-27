set -o errexit
set -o nounset
set -o pipefail

function main {
  groups="$1"
  user_specified_files=("${@:2}")

  lefthook_command=(lefthook run pre-push)
  if [ "$groups" != 'all' ]; then
    lefthook_command=("${lefthook_command[@]}" --commands "$groups")
  fi

  if [ -n "${ALL_FILES:-}" ]; then
    "${lefthook_command[@]}" --all-files
  elif [ "${#user_specified_files[@]}" -gt 0 ]; then
    printf '%s\0' "${user_specified_files[@]}" |
      "${lefthook_command[@]}" --files-from-stdin
  else
    get_files_that_differ_from_default_branch |
      "${lefthook_command[@]}" --files-from-stdin
  fi
}

function get_files_that_differ_from_default_branch {
  remote="${GIT_REMOTE:-origin}"
  git diff -z --diff-filter=d --name-only "$remote/HEAD"
  # Untracked files
  git ls-files -z --others --exclude-standard
}

main "$@"
