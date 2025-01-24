#! /usr/bin/env nix-shell
#! nix-shell -I nixpkgs=./nix/nixpkgs.nix
#! nix-shell -i bash
#! nix-shell --packages "with (import ../nix/flake-package-set.nix); [bash direnv coreutils]"

# This script is for running direnv commands. It handles things that need to be done
# before running direnv:
#   - Get direnv and Bash, using the nix-shell shebang at the top
#   - Copy the sample .envrc to where direnv expects it to be
#   - Run `direnv allow`
#
# Since this script is not run from within the direnv environment, the shebang at the
# top works differently than the ones in other scripts:
#   - A relative path is used to access the package set instead of the
#     FLAKE_PACKAGE_SET_FILE environment variable. This is done because that variable
#     comes from the direnv environment.
#   - -I is used to set nixpkgs on the nix path. This is done because NIX_PATH is set
#     by the direnv environment.
#   - nix-shell is used instead of cached-nix-shell. This is done because
#     cached-nix-shell comes from the direnv environment.
#   - bash is used as the interpreter instead of nix-shell-interpreter. This is
#     because nix-shell-interpreter is only needed to work around an issue with
#     cached-nix-shell.
#
# Also worth noting that the path in -I is relative to the directory where this
# script is executed and the path in the import is relative to where the script file
# is.

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

if [[ ! -e .envrc ]]; then
  cp direnv/envrc-sample.bash .envrc
fi
direnv allow .
direnv "$@"
