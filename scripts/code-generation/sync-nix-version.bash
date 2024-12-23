#! /usr/bin/env cached-nix-shell
#! nix-shell --keep PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"PACKAGES\")); [nix-shell-interpreter gnused]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

version="$(nix eval --impure --expr '(import ./nix/packages.nix).nix.version' --raw)"
sed --regexp-extended --in-place \
  "s/\/nix-[0-9]+(\.[0-9]+){0,2}/\/nix-$version/g" \
  README.md
