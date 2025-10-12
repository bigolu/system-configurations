#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter coreutils
#MISE description="Start a Bash shell in an environment that resembles CI"
#USAGE arg "<nix_dev_shell>" help="The dev shell to load"
#USAGE complete "nix_dev_shell" run=#" nix eval --raw --file . devShells --apply 'with builtins; shells: concatStringsSep "\n" (filter (name: substring 0 (stringLength "ci-") name == "ci-") (attrNames shells))' "#

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# Isolate the environment by using temporary directories for any directory that may
# be read from or written to.
temp_home="$(mktemp --directory)"
temp_dev_shell_state="$(mktemp --directory)"
function clean_up {
  # Go doesn't set the write permission on the directories it creates[1] so we have
  # to do that before deleting them.
  #
  # [1]: https://github.com/golang/go/issues/27161#issuecomment-418906507
  if [[ -e "$temp_home/go" ]]; then
    chmod -R +w "$temp_home/go"
  fi
  rm -rf "$temp_home" "$temp_dev_shell_state"
}
trap clean_up EXIT

# Since we only assume that the CI machine has nix and git, they're the only programs
# added to the nix shell. We need git since flake-compat uses `builtins.fetchGit`
# which depends on it[1].
#
# [1]: https://github.com/NixOS/nix/issues/3533
nix shell \
  --ignore-environment \
  --set-env-var HOME "$temp_home" \
  --set-env-var DEV_SHELL_STATE "$temp_dev_shell_state" \
  --file nix/packages nix git \
  --command nix run --file . "devShells.${usage_nix_dev_shell:?}"
