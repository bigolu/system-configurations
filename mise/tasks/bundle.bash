#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter]"
#MISE description='Create a bundle'
#USAGE long_about """
#USAGE   Create a bundle for the specified package using the bundler in this \
#USAGE   repository.
#USAGE """
#USAGE arg "<package>" help="The package to build e.g. .#shell"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

nix bundle --bundler .# "${usage_package:?}"
