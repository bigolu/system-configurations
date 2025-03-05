#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# Lets me start a nix shell with python and the specified python packages.
# Example: `pynix requests marshmallow`

function main {
  readarray -d '' packages < <(printf "p.%s\0" "$@")

  joined_packages="$(printf '%s ' "${packages[@]}")"
  joined_packages="${joined_packages::-1}"

  nix shell --impure --expr "(import (builtins.getFlake \"nixpkgs\") {}).python3.withPackages (p: [$joined_packages])"
}

main "$@"
