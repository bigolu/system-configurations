#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep FLAKE_INTERNAL_PACKAGE_SET
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_INTERNAL_PACKAGE_SET\")); [nix-shell-interpreter jq perl]"
#MISE hide=true

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

commit="$(nix eval --raw --file nix/flake/compat.nix 'inputs.nixpkgs.rev')"

perl -0777 -w -s -i -pe \
  's{(nixpkgs/)[^\s]{40}( )}{$1$commit$2}igs' \
  -- -commit="$commit" \
  README.md
