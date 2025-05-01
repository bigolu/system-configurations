#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep FLAKE_INTERNAL_PACKAGE_SET
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_INTERNAL_PACKAGE_SET\")); [nix-shell-interpreter coreutils fd nvd nix-output-monitor]"
#MISE hide=true

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

function main {
  old_dev_shell="$(get_dev_shell_store_path)"
  direnv-reload |& nom
  new_dev_shell="$(get_dev_shell_store_path)"
  nvd --color=never diff "$old_dev_shell" "$new_dev_shell"
}

# Prints the store path for the dev shell that is currently cached by nix-direnv.
function get_dev_shell_store_path {
  flake_profile="$(fd --no-ignore --type symlink --exclude '*.rc' 'flake-profile-.*' .direnv)"
  readlink --canonicalize "$flake_profile"
}

main "$@"
