set -o errexit
set -o nounset
set -o pipefail

function main {
  readarray -d '' untracked_files < <(git ls-files -z --others --exclude-standard)

  track_files "${untracked_files[@]}"

  repository_state_before_running="$(git diff)"
  "$@"
  repository_state_after_running="$(git diff)"

  untrack_files "${untracked_files[@]}"

  if [ "$repository_state_before_running" != "$repository_state_after_running" ]; then
    return 1
  else
    return 0
  fi
}

function track_files {
  for file in "$@"; do
    git add --intent-to-add -- "$file"
  done
}

function untrack_files {
  for file in "$@"; do
    git reset --quiet -- "$file"
  done
}

main "$@"
