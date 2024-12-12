#! /usr/bin/env cached-nix-shell
#! nix-shell --keep PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"PACKAGES\")); [nix-shell-interpreter curl coreutils perl]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

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
