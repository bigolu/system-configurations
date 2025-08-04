#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
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

"$opener" "$PWD/task-docs.html"
