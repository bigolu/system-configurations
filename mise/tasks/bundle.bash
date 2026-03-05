#!
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter
#MISE description='Create a bundle'
#USAGE long_about "Create a bundle for the specified package using the bundler in this repository."
#USAGE arg "<attr_path>" help="The attribute path of the package to build e.g. packages.shell"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

nix build --impure --expr "with (import ./. {}); bundlers.rootless ${usage_attr_path:?}"
