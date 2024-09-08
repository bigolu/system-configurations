set -o errexit
set -o nounset
set -o pipefail

readarray -d '' files < <(fd --print0 --hidden --extension md)
markdownlint-cli2 "$@" "${files[@]}"
