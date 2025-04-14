#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter]"
#MISE description='Run `nix build` in debug mode'
#USAGE arg "<flakeref>" help="The flakeref of the derivation to build e.g. `.#shell`"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

nix build --impure --ignore-try --debugger --print-out-paths --no-link "${usage_flakeref:?}"
