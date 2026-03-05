#!
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter
#MISE description="Open task documentation"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

if [[ $OSTYPE == linux* ]]; then
  opener='xdg-open'
else
  opener='open'
fi

"$opener" "$PWD/docs/tasks.html"
