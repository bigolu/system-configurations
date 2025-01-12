#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter coreutils nix-output-monitor]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

function main {
  old_dev_shell="$(get_dev_shell_store_path)"
  # nix-direnv will only reload the dev shell if its cache is invalid. nix-direnv
  # only considers its cache invalid when one of the files tracked by direnv changes.
  # Rather than adding all of the files that affect the dev shell to direnv's tracked
  # files, I touch one of the files that I know is already tracked, flake.nix.
  touch flake.nix && nix-direnv-reload |& nom
  new_dev_shell="$(get_dev_shell_store_path)"

  # On the first sync, there won't be an old dev shell
  if [[ -n $old_dev_shell ]]; then
    nix store diff-closures "$old_dev_shell" "$new_dev_shell"
  fi
}

# Prints the store path to the dev shell that is currently cached by nix-direnv.
# Prints nothing if nix-direnv has not cached a dev shell.
function get_dev_shell_store_path {
  flake_profile=''
  # This glob will match two files that are created by nix-direnv:
  # flake-profile-<hash> and flake-profile-<hash>.rc. The one that doesn't end in .rc
  # will be a symlink to the dev shell store path.
  for flake_profile_candidate in ".direnv/flake-profile-"*; do
    if [[ $flake_profile_candidate != *.rc ]]; then
      flake_profile="$flake_profile_candidate"
      break
    fi
  done

  if [[ -n $flake_profile ]]; then
    # Prints the target of the symlink i.e. the dev shell store path
    readlink --canonicalize "$flake_profile"
  fi
}

main "$@"
