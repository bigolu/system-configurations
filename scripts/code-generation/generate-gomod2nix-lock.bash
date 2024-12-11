#! /usr/bin/env cached-nix-shell
#! nix-shell --keep NIXPKGS
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIXPKGS\") {}); [nix-shell-interpreter]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

cd ./flake-modules/bundler/gozip

nix develop .#gomod2nix --command gomod2nix generate
