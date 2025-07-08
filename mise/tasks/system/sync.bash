#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter home-manager darwin-rebuild nix-output-monitor]"
#MISE hide=true
#USAGE arg "[config]" help="The name of the configuration to apply"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

flakeref=".#${usage_config:-$(<"${XDG_STATE_HOME:-$HOME/.local/state}/bigolu/system-config-name")}"
if [[ $OSTYPE == linux* ]]; then
  home-manager switch -b backup --flake "$flakeref"
else
  sudo darwin-rebuild switch --flake "$flakeref"
fi |& nom
