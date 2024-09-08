#!/usr/bin/env bash

# Lets me starts a nix shell with python and the specified python packages.
# Example: `pynix requests marshmallow`

readarray -d '' packages < <(printf "nixpkgs#python3Packages.%s\0" "$@")
nix shell "${packages[@]}"
