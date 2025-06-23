#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# Lets me start a nix shell with python and the specified python packages.
# Example: `pynix requests marshmallow`

readarray -d '' packages < <(printf "p.%s\0" "$@")
IFS=' ' joined_packages="${packages[*]}"
nix shell --impure --expr \
  "(import <nixpkgs> {}).python3.withPackages (p: [$joined_packages])"
