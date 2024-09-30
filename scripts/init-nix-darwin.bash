#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.curl local#nixpkgs.coreutils --command bash

# shellcheck shell=bash

set -o errexit
set -o nounset
set -o pipefail

if ! [ -x /usr/local/bin/brew ]; then
  # Install homebrew. Source: https://brew.sh/
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

original_conf='/etc/nix/nix.conf'
backup="$original_conf".before-nix-darwin
if [ -f "$original_conf" ]; then
  if ! [ -f "$backup" ]; then
    mv "$original_conf" "$backup"

    # Since there isn't a nix.conf anymore, we have to re-enable any necessary
    # experimental features.
    export NIX_CONFIG="$NIX_CONFIG"$'\n''extra-experimental-features = nix-command flakes'
  fi
fi

nix run .#nixDarwin -- switch --flake .#"$1"
