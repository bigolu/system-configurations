#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter coreutils fd nvd nix-output-monitor]"

# This script reloads the direnv environment. Since I've disabled nix-direnv's auto
# reload, I'll reload it here as well.

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

function main {
  old_dev_shell="$(get_dev_shell_store_path)"
  nix-direnv-reload |& nom
  direnv-reload
  new_dev_shell="$(get_dev_shell_store_path)"
  nvd --color=never diff "$old_dev_shell" "$new_dev_shell"
}

# Prints the store path for the dev shell that is currently cached by nix-direnv.
function get_dev_shell_store_path {
  flake_profile="$(fd --no-ignore --type symlink --exclude '*.rc' 'flake-profile-.*' .direnv)"
  readlink --canonicalize "$flake_profile"
}

main "$@"
