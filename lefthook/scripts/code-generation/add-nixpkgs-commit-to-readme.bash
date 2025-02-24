#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter jq perl]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

commit="$(
  nix flake metadata --json |
    jq --raw-output '.locks.nodes.nixpkgs.locked.rev'
)"

perl -0777 -w -s -i -pe \
  's{(nixpkgs/)[^\s]{40}( )}{$1$commit$2}igs' \
  -- -commit="$commit" \
  README.md
