#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter gnused]"
#MISE hide=true

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

version="$(nix eval --raw --file nix/flake-package-set.nix 'nix.version')"
sed --regexp-extended --in-place \
  "s/\/nix-[0-9]+(\.[0-9]+){0,2}/\/nix-$version/g" \
  README.md
