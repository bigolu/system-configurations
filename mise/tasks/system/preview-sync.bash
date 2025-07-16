#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter nvd
#MISE description='Preview system config application'
#USAGE long_about """
#USAGE   Show a preview of what changes would be made to the system if you applied \
#USAGE   the current configuration.
#USAGE """

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

config="$(<"${XDG_STATE_HOME:-$HOME/.local/state}/bigolu/system-config-name")"
if [[ $OSTYPE == linux* ]]; then
  oldGenerationPath="${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/home-manager"
  newGenerationPath="$(
    nix build --no-link --print-out-paths --file . "homeConfigurations.${config}.activationPackage"
  )"
else
  oldGenerationPath=/nix/var/nix/profiles/system
  newGenerationPath="$(
    nix build --no-link --print-out-paths --file . "darwinConfigurations.${config}.system"
  )"
fi

nvd --color=never diff "$oldGenerationPath" "$newGenerationPath"
