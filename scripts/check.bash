set -o errexit
set -o nounset
set -o pipefail

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
  bash scripts/get-files-that-differ-from-default-branch.bash |
    "${lefthook_command[@]}" --files-from-stdin
fi
