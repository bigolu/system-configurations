#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.findutils local#nixpkgs.jq --command bash

# shellcheck shell=bash

# Make sure everything builds. This is necessary since I use nixpkgs-unstable.

set -o errexit
set -o nounset
set -o pipefail

# Build devShells
nix flake show --json |
  jq ".devShells.\"$(nix show-config system)\"|keys[]" |
  xargs -I {} nix develop .#{} --command bash -c ':'

# Build packages. We don't need to build the host manager activation packages
# since they are included in the default package i.e. the meta-package
# containing all packages to cache.
nix flake show --json |
  jq ".packages.\"$(nix show-config system)\"|keys[]" |
  # Allow unfree since the terminal* packages use nvidia drivers
  xargs -I {} nix build --no-link .#{}
