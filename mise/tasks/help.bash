#nix --interpreter bash
#nix --packages bash
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
