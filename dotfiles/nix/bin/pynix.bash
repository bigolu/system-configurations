#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# Lets me starts a nix shell with python and the specified python packages.
# Example: `pynix requests marshmallow`

function main {
  readarray -d '' packages < <(printf "p.%s\0" "$@")
  nix shell --impure --expr "(import (builtins.getFlake \"nixpkgs\") {}).python3.withPackages (p: [$(join ' ' "${packages[@]}")])"
}

# source: https://stackoverflow.com/a/17841619
function join {
  local d=${1-} f=${2-}
  if shift 2; then
    printf %s "$f" "${@/#/$d}"
  fi
}

main "$@"
