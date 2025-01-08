#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter gomod2nix]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

go_mod_directory="$1"

# If there isn't already a gomod2nix lock in the same directory as go.mod, then I
# assume this project isn't using gomod2nix.
if [[ ! -e $go_mod_directory/gomod2nix.toml ]]; then
  exit
fi

gomod2nix --dir "$go_mod_directory" generate
