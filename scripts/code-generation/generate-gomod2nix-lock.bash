#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash --command bash

# shellcheck shell=bash

set -o errexit
shopt -s inherit_errexit
set -o nounset
set -o pipefail
shopt -s nullglob

cd ./flake-modules/bundler/gozip
nix develop --inputs-from . gomod2nix# --command gomod2nix generate
