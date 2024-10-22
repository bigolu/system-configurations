#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.gnused --command bash

# shellcheck shell=bash

set -o errexit
set -o nounset
set -o pipefail

version="$(nix --version)"
version_number="${version##* }"
files=(.github/actions/setup/action.yml README.md)
for file in "${files[@]}"; do
  sed -i "s/\/nix-[0-9]*\.[0-9]*\.[0-9]*/\/nix-$version_number/g" "$file"
done
