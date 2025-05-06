#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter gomod2nix]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

go_mod_directory="$1"

# If there isn't already a gomod2nix lock in the same directory as go.mod, then I
# assume this project isn't using gomod2nix.
if [[ ! -e $go_mod_directory/gomod2nix.toml ]]; then
  exit
fi

gomod2nix --dir "$go_mod_directory" generate
