#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter nix-fast-build]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

current_system="$(nix eval --raw --impure --expr 'builtins.currentSystem')"
nix-fast-build \
  --no-nom \
  --skip-cached \
  --flake ".#allSystems.${current_system}.allModuleArgs.pkgs.packagesToCache"
