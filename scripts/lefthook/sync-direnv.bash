#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter coreutils fd nix-output-monitor]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

function main {
  old_dev_shell="$(get_dev_shell_store_path)"
  direnv-reload |& nom
  new_dev_shell="$(get_dev_shell_store_path)"
  nix store diff-closures "$old_dev_shell" "$new_dev_shell"
}

# Prints the store path for the dev shell that is currently cached by nix-direnv.
function get_dev_shell_store_path {
  flake_profile="$(fd --type symlink --exclude '*.rc' 'flake-profile-.*' .direnv)"

  if [[ -n $flake_profile ]]; then
    # Prints the target of the symlink i.e. the dev shell store path
    readlink --canonicalize "$flake_profile"
  fi
}

main "$@"
