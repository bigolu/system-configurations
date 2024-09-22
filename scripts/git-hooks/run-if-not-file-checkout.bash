set -o errexit
set -o nounset
set -o pipefail

if [ "$3" != '0' ]; then
  "$@"
fi
