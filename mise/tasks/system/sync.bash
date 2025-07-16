#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter home-manager darwin-rebuild nix-output-monitor coreutils
#MISE hide=true
#USAGE arg "[config]" help="The name of the configuration to apply"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# TODO: It would be nice if these tools accepted a file and an attribute path, like
# the new nix CLI.

config="${usage_config:-$(<"${XDG_STATE_HOME:-$HOME/.local/state}/bigolu/system-config-name")}"
if [[ $OSTYPE == linux* ]]; then
  HOME_MANAGER_BACKUP_EXT='backup' \
    "$(nix build --no-link --print-out-paths --file . "homeConfigurations.$config.activationPackage")/activate"
else
  temp="$(mktemp --suffix '.nix')"
  echo "(import $PWD {}).darwinConfigurations.$config" >"$temp"
  sudo darwin-rebuild switch -I "darwin=$temp"
fi |& nom
