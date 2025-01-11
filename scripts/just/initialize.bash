#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

manager="$1"
config="$2"

if [[ $manager == 'home-manager' ]]; then
  just home-manager "$config"
elif [[ $manager == 'nix-darwin' ]]; then
  just nix-darwin "$config"
else
  echo "Unknown system manager: $manager" >&2
  exit 1
fi
