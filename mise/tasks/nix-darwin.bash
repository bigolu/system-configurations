#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter curl darwin-rebuild nix-output-monitor gitMinimal]"
#MISE hide=true
#USAGE arg "<configuration>"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

if ! [[ -x /usr/local/bin/brew ]]; then
  # Install homebrew. Source: https://brew.sh/
  homebrew_install_script="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  /bin/bash -c "$homebrew_install_script"
fi

# Tell nix-darwin the hash of my nix.conf so it can overwrite it. You can find more
# information in the comment where this file is read.
hash_file='nix/flake-modules/darwin-configurations/modules/nix/nix-conf-hash.txt'
shasum -a 256 /etc/nix/nix.conf | cut -d ' ' -f 1 >"$hash_file"
function undo_hash_file_changes {
  git checkout -- "$hash_file"
}
trap undo_hash_file_changes EXIT

# Before applying the config with the real Linux builder, apply the config with the
# bootstrap builders.
builder_file='nix/flake-modules/darwin-configurations/modules/nix/linux-builder-config-name.txt'
for builder in bootstrap1 bootstrap2 "$(<"$builder_file")"; do
  echo "$builder" >"$builder_file"
  darwin-rebuild switch --flake .#"${usage_configuration:?}" |& nom
done
