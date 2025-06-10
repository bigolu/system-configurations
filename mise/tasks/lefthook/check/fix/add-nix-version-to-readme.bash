#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter gnused]"
#MISE hide=true

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

version="$(nix eval --raw --file nix/packages.nix 'nix.version')"
perl -0777 -wsi \
  -pe '$count += s{(nix-)[0-9]+(?:\.[0-9]+){0,2}}{$1$version}gs;' \
  -e 'END { die "failed to substitute" if $count != 2 }' \
  -- \
  -version="$version" \
  README.md
