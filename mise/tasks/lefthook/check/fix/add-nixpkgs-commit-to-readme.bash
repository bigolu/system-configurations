#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter jq perl]"
#MISE hide=true

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

commit="$(nix eval --raw --file nix/flake/compat.nix 'inputs.nixpkgs.rev')"

perl -wsi \
  -pe '$count += s{(nixpkgs/)[^\s]{40}( )}{$1$commit$2}s;' \
  -e 'END { die "failed to substitute" if $count != 1 }' \
  -- \
  -commit="$commit" \
  README.md
