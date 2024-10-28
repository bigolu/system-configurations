#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.gnused --command bash

# shellcheck shell=bash

set -o errexit
set -o nounset
set -o pipefail

# shellcheck disable=2016
version="$(
  nix eval \
    --raw --impure --expr \
    '(import ./default.nix).outputs.legacyPackages.${builtins.currentSystem}.nixpkgs.nix.version'
)"
sed --regexp-extended --in-place \
  "s/\/nix-[0-9]+(\.[0-9]+){0,2}/\/nix-$version/g" \
  .github/actions/setup/action.yml \
  README.md
