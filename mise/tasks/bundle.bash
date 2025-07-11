#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter
#MISE description='Create a bundle'
#USAGE long_about """
#USAGE   Create a bundle for the specified package using the bundler in this \
#USAGE   repository.
#USAGE """
#USAGE arg "<flakeref>" help="The flakeref of the package to build e.g. .#shell"
#USAGE complete "flakeref" run=#"""
#USAGE   fish -c 'complete --do-complete "nix bundle --bundler .# {{words[CURRENT]}}"'
#USAGE """#

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

nix bundle --bundler .# "${usage_flakeref:?}"
