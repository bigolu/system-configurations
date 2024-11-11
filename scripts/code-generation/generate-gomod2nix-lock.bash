#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash --command bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

cd ./flake-modules/bundler/gozip

# It stopped working. This open issue shows the same error I got:
# https://github.com/nix-community/gomod2nix/issues/172
# nix develop --inputs-from . gomod2nix# --command gomod2nix generate
