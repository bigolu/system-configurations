#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter coreutils
#MISE description="Start a Bash shell in an environment that resembles CI"
#USAGE arg "<nix_dev_shell>" help="The dev shell to load"
#USAGE complete "nix_dev_shell" run=#"""
#USAGE   nix eval \
#USAGE     --file . devShells \
#USAGE     --apply 'shells: builtins.concatStringsSep "\n" (builtins.attrNames shells)' \
#USAGE     --raw
#USAGE """#

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# Isolate the environment using temporary directories
temp_home="$(mktemp --directory)"
direnv_layout_dir="$(mktemp --directory)"
temp_dev_shell_state="$(mktemp --directory)"

function clean_up {
  # Go doesn't set the write permission on the directories it creates[1] so we have
  # to do that before deleting them.
  #
  # [1]: https://github.com/golang/go/issues/27161#issuecomment-418906507
  if [[ -e "$temp_home/go" ]]; then
    chmod -R +w "$temp_home/go"
  fi
  rm -rf "$direnv_layout_dir" "$temp_home" "$temp_dev_shell_state"
}
trap clean_up EXIT

# Use a nix shell to create an environment that resembles a CI runner's environment.
#
# flake-compat uses `builtins.fetchGit` which depends on git
# https://github.com/NixOS/nix/issues/3533
nix shell \
  --ignore-environment \
  --set-env-var HOME "$temp_home" \
  --set-env-var direnv_layout_dir "$direnv_layout_dir" \
  --set-env-var DEV_SHELL_STATE "$temp_dev_shell_state" \
  --set-env-var CI true \
  --set-env-var CI_DEBUG true \
  --file nix/packages nix git \
  --command nix run --file . "devShells.${usage_nix_dev_shell:?}"
