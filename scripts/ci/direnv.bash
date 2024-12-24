#! /usr/bin/env nix-shell
#! nix-shell -i bash
#! nix-shell --packages "with (import ../../nix/flake-package-set.nix); [bash direnv]"

# ^ Note the use of a relative path to access the package set instead of the FLAKE_PACKAGE_SET_FILE
# environment variable. That is because this script is used as part of loading a
# direnv environment, so FLAKE_PACKAGE_SET_FILE won't be set yet.

# This script is for executing direnv commands in CI. It does a few things:
#   - Get direnv and bash, using the nix-shell shebang at the top
#   - Automatically call `direnv allow`

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

direnv allow .
direnv "$@"
