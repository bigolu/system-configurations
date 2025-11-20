set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

configuration="${1:?}"

if [[ ! -d ~/code/system-configurations ]]; then
  git clone https://github.com/bigolu/system-configurations.git ~/code/system-configurations
fi
cd ~/code/system-configurations
if [[ ! -e .envrc ]]; then
  echo "source direnv-recommended.bash" >.envrc
fi
direnv allow
direnv_export="$(direnv export bash)"
eval "$direnv_export"

if [[ $OSTYPE == linux* ]]; then
  mise run system-sync "$configuration"
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
    mise run system-sync "$configuration"
  done
fi

mise run sync
