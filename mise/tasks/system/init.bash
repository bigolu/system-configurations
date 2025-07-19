#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter coreutils git
#MISE description='Initialize the system'
#MISE hide=true
#MISE depends_post='sync'
#USAGE arg "<configuration>" help="The name of the configuration to apply"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

if [[ $OSTYPE == linux* ]]; then
  mise run system:sync "${usage_configuration:?}"
  # shellcheck disable=2016
  echo 'Consider copying COSMIC settings to the system by running `mise run copy-cosmic to-system`'
else
  if ! [[ -x /usr/local/bin/brew ]]; then
    # Install homebrew. Source: https://brew.sh/
    homebrew_install_script="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    /bin/bash -c "$homebrew_install_script"
  fi

  hash_file='nix/outputs/darwinConfigurations/comp_2/modules/comp-2/nix/nix-conf-hash.txt'
  builder_file='nix/outputs/darwinConfigurations/comp_2/modules/comp-2/nix/linux-builder-config-name.txt'
  function undo_file_changes {
    git checkout -- "$hash_file" "$builder_file"
  }
  trap undo_file_changes EXIT

  # Tell nix-darwin the hash of my nix.conf so it can overwrite it. You can find more
  # information in the comment where this file is read.
  shasum -a 256 /etc/nix/nix.conf | cut -d ' ' -f 1 >"$hash_file"

  # Apply the config with the bootstrap builders.
  for builder in bootstrap1 bootstrap2; do
    echo "$builder" >"$builder_file"
    mise run system:sync "${usage_configuration:?}"
  done
fi
