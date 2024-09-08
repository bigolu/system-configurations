set -o errexit
set -o nounset
set -o pipefail

readarray -d '' files < <(fd --print0 --hidden --extension fish)
# TODO: fish doesn't support passing multiple files I should open an issue
for file in "${files[@]}"; do
  fish --no-execute "$@" "$file"
done
