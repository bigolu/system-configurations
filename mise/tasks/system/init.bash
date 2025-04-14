#! Though we don't use shebangs, nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter coreutils home-manager curl darwin-rebuild nix-output-monitor gitMinimal]"
#MISE description='Initialize the system'
#MISE hide=true
#MISE depends_post='sync:force'
#USAGE arg "<configuration>" help="The name of the configuration to apply"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

kernel="$(uname)"
if [[ $kernel == 'Linux' ]]; then
  home-manager switch --flake .#"${usage_configuration:?}"
  bash dotfiles/firefox-developer-edition/set-default-browser.bash
  # shellcheck disable=2016
  echo 'Consider copying COSMIC settings to the system by running `mise run copy-cosmic to-system`'
else
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

  # Apply the config with the bootstrap builders.
  builder_file='nix/flake-modules/darwin-configurations/modules/nix/linux-builder-config-name.txt'
  my_builder="$(<"$builder_file")"
  for builder in bootstrap1 bootstrap2; do
    echo "$builder" >"$builder_file"
    darwin-rebuild switch --flake .#"${usage_configuration:?}" |& nom
  done
  echo "$my_builder" >"$builder_file"
fi
