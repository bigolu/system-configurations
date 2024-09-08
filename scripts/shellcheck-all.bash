set -o errexit
set -o nounset
set -o pipefail

readarray -d '' scripts < <(fd --print0 --hidden --extension bash --extension sh)
shellcheck "$@" "${scripts[@]}"
