set -o errexit
set -o nounset
set -o pipefail

# It's just a file checkout so exit
if [ "$3" = '0' ]; then
  exit
fi

bash ./.git-hook-assets/on-change.bash
