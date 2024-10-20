#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.curl local#nixpkgs.coreutils --command bash

# shellcheck shell=bash

set -o errexit
set -o nounset
set -o pipefail

if ! [[ -x /usr/local/bin/brew ]]; then
  # Install homebrew. Source: https://brew.sh/
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

original_conf='/etc/nix/nix.conf'
backup="$original_conf".before-nix-darwin
if [[ -f "$original_conf" ]]; then
  if ! [[ -f "$backup" ]]; then
    mv "$original_conf" "$backup"

    # Since we moved the nix.conf, load it into an environment variable.
    NIX_CONFIG="$(<"$backup")"
    export NIX_CONFIG
  fi
fi

# Run as root so NIX_CONFIG will be respected.
#
# To avoid having root directly manipulate the store, explicitly set the daemon.
# Source: https://docs.lix.systems/manual/lix/stable/installation/multi-user.html#multi-user-mode
sudo --preserve-env=PATH,NIX_CONFIG nix run --eval-store daemon .#nixDarwin -- switch --flake .#"$1"
