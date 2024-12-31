#! /usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell --packages "with (import ../../nix/flake-package-set.nix); [bash direnv]"

# This script is for running direnv commands in CI. It takes care of things that need
# to be done before running direnv:
#   - Get direnv and bash, using the nix-shell shebang at the top
#   - Run `direnv allow`
#
# Since this script is used to load the direnv environment, it's not run from within
# the environment. Because of this, the shebang at the top works differently than the
# ones in other scripts:
#   - A relative path is used to access the package set instead of the
#     FLAKE_PACKAGE_SET_FILE environment variable. This is done because that variable
#     comes from the direnv environment.
#   - nix-shell is used instead of cached-nix-shell. This is done because
#     cached-nix-shell comes from the direnv environment.

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

direnv allow .
direnv "$@"
