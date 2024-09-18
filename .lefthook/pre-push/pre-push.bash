set -o errexit
set -o nounset
set -o pipefail

readarray -t lines
for line in "${lines[@]}"; do
  IFS=" " read -ra parts <<<"$line"
  sha="${parts[1]}"
  echo "$sha"
done
