#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter coreutils bash
#MISE description="Start a Bash shell in a direnv CI environment"
#USAGE arg "<nix_dev_shell>" help="The dev shell that direnv should load"
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

# Create an isolated environment with temporary directories
temp_home="$(mktemp --directory)"
direnv_layout_dir="$(mktemp --directory)"
temp_dev_shell_state="$(mktemp --directory)"

bash_path="$(type -P bash)"

function clean_up {
  # Go doesn't set the write permission on the directories it creates[1] so we have
  # to do that before deleting them.
  #
  # [1]: https://github.com/golang/go/issues/27161#issuecomment-418906507
  chmod -R +w "$temp_home/go"
  rm -rf "$direnv_layout_dir" "$temp_home" "$temp_dev_shell_state"
}
trap clean_up EXIT

# flake-compat uses `builtins.fetchGit` which depends on git
# https://github.com/NixOS/nix/issues/3533
nix shell \
  --ignore-environment \
  --set-env-var HOME "$temp_home" \
  --set-env-var direnv_layout_dir "$direnv_layout_dir" \
  --set-env-var DEV_SHELL_STATE "$temp_dev_shell_state" \
  --set-env-var NIX_DEV_SHELL "${usage_nix_dev_shell:?}" \
  --set-env-var CI true \
  --set-env-var CI_DEBUG true \
  --file nix/packages nix git \
  --command nix run --file nix/packages direnv-wrapper -- direnv.bash exec . "$bash_path" --noprofile --norc
