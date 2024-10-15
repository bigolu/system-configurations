#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.gh local#nixpkgs.doppler --command bash

# shellcheck shell=bash

set -o errexit
set -o nounset
set -o pipefail

if ! gh auth status 1>/dev/null 2>&1; then
  doppler secrets get GITHUB_PAT --plain | gh auth login --with-token
fi

gh "$@"
