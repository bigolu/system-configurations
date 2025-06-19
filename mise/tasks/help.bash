#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter coreutils]"
#MISE description="Open task documentation"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

kernel="$(uname)"
if [[ $kernel == 'Linux' ]]; then
  opener='xdg-open'
else
  opener='open'
fi

"$opener" "$PWD/docs/tasks.html"
