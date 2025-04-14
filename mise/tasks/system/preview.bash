#! Though we don't use shebangs, nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter]"
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

system-config-preview
