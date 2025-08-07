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

# You can change direnv's layout directory by setting `direnv_layout_dir`. By
# default, it's `.direnv`. Why we change this:
#   - So direnv doesn't overwrite the development environment in `.direnv`.
#   - Using a new `direnv_layout_dir` would be a more accurate representation of CI
#     since `direnv_layout_dir` will start off empty there.
direnv_layout_dir="$(mktemp --directory)"
temp_home="$(mktemp --directory)"
bash_path="$(type -P bash)"

nix shell \
  --ignore-environment \
  --set-env-var HOME "$temp_home" \
  --set-env-var NIX_DEV_SHELL "${usage_nix_dev_shell:?}" \
  --set-env-var CI true \
  --set-env-var CI_DEBUG true \
  --set-env-var direnv_layout_dir "$direnv_layout_dir" \
  --file nix/packages nix \
  --command nix run --file nix/packages direnv-wrapper -- direnv.bash exec . "$bash_path" --noprofile --norc
