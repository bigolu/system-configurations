set -o errexit
set -o nounset
set -o pipefail

readarray -d '' scripts < <(fd --print0 --hidden --extension md)
# Don't let stdout be a tty so ltex-cli doesn't use colors
ltex-cli --server-command-line=ltex-ls "$@" "${scripts[@]}" | cat
exit "${PIPESTATUS[1]}"
