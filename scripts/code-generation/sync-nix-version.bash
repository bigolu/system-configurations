#! /usr/bin/env cached-nix-shell
#! nix-shell --keep NIXPKGS
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIXPKGS\") {}); [nix-shell-interpreter gnused]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

version="$(
  nix eval \
    --raw --impure --expr \
    '(import ./nixpkgs.nix {}).nix.version'
)"
sed --regexp-extended --in-place \
  "s/\/nix-[0-9]+(\.[0-9]+){0,2}/\/nix-$version/g" \
  README.md
