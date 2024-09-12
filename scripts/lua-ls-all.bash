set -o errexit
set -o nounset
set -o pipefail

tmp="$(mktemp --directory)"
lua-language-server --logpath "$tmp" --checklevel=Information --check . 1>/dev/null 2>&1
result="$(cat "$tmp"/check.json)"
if [ "$result" != '[]' ]; then
  echo "$result"
  exit 1
fi
