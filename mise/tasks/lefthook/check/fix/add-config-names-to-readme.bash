#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter perl]"
#MISE hide=true

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

configs="$(nix eval --raw --file nix/config-names.nix)"

perl -0777 -wsi \
  -pe '$count += s{(system:init <).*?(>)}{$1$configs$2}s;' \
  -e 'END { die "failed to substitute" if $count != 1 }' \
  -- \
  -configs="$configs" \
  README.md
