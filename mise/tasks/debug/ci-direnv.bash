#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter coreutils bash
#MISE description="Start a Bash shell in a direnv CI environment"
#USAGE arg "<nix_dev_shell>" help="The dev shell that direnv should load"
#USAGE complete "nix_dev_shell" run=#"""
#USAGE   nix eval \
#USAGE     --file default.nix devShells \
#USAGE     --apply 'shells: builtins.concatStringsSep "\n" (builtins.attrNames shells)' \
#USAGE     --raw
#USAGE """#

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# You can change direnv's layout directory by setting `direnv_layout_dir`. If it's
# not set, .direnv is used. I'm changing it so nix-direnv doesn't overwrite the dev
# shell cached in .direnv with the one built here.
direnv_layout_dir="$(mktemp --directory)"

bash_path="$(type -P bash)"

# Keep HOME so nix's cache in ~/.cache/nix can be reused
nix shell \
  --ignore-environment \
  --keep HOME \
  --set-env-var NIX_DEV_SHELL "${usage_nix_dev_shell:?}" \
  --set-env-var CI true \
  --set-env-var CI_DEBUG true \
  --set-env-var direnv_layout_dir "$direnv_layout_dir" \
  --file nix/dev/packages.nix nix \
  --command nix-shell direnv/direnv-wrapper.bash direnv/config/ci.bash exec . "$bash_path" --noprofile --norc
