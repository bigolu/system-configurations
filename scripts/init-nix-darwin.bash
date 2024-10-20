#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.curl local#nixpkgs.coreutils local#nixpkgs.perl --command bash

# shellcheck shell=bash

set -o errexit
set -o nounset
set -o pipefail

if ! [[ -x /usr/local/bin/brew ]]; then
  # Install homebrew. Source: https://brew.sh/
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

hash_file='flake-modules/nix-darwin/nix-conf-hash.txt'

# Tell nix-darwin the hash of my nix.conf so it can overwrite it. You can find more
# information in the comment where this file is read.
shasum -a 256 /etc/nix/nix.conf | cut -d ' ' -f 1 >"$hash_file"

nix run .#nixDarwin -- switch --flake .#"$1"

git checkout -- "$hash_file"
