set -o errexit
set -o nounset
set -o pipefail

readarray -d '' files < <(fd --print0 --hidden --extension desktop)
desktop-file-validate "$@" "${files[@]}"
