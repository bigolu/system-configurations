set -o errexit
set -o nounset
set -o pipefail

tmp="$(mktemp --directory)"
chronic lua-language-server --logpath "$tmp" --checklevel=Information --check .
result="$(cat "$tmp"/check.json)"
if [ "$result" != '[]' ]; then
  echo "$result"
  exit 1
fi
