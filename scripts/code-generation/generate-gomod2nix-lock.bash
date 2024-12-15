#! /usr/bin/env cached-nix-shell
#! nix-shell --keep PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"PACKAGES\")); [nix-shell-interpreter gomod2nix]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

cd ./gozip

gomod2nix generate
