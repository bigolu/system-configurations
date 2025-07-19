#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter
#MISE description='Run `nix build` in debug mode'
#USAGE arg "<attr_path>" help="The attribute path of the package to build e.g. packages.shell"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

nix build --impure --ignore-try --debugger --print-out-paths --no-link --file . "${usage_attr_path:?}"
