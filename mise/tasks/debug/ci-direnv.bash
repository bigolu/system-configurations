#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter coreutils]"
#MISE description="Start a Bash shell in a direnv CI environment"
#USAGE arg "<nix_dev_shell>" help="The dev shell that direnv should load"
#USAGE complete "nix_dev_shell" run=#"""
#USAGE   fish -c 'complete --do-complete "nix develop .#ci-" | string sub --start 3'
#USAGE """#

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

environment_variables=(
  NIX_DEV_SHELL="${usage_nix_dev_shell:?}"
  CI=true
  CI_DEBUG=true

  # You can change direnv's layout directory by setting `direnv_layout_dir`. If it's
  # not set, .direnv is used. I'm changing it so nix-direnv doesn't overwrite the dev
  # shell cached in .direnv with the one built here.
  direnv_layout_dir="$(mktemp --directory)"
)
environment_variable_flags=()
for var in "${environment_variables[@]}"; do
  environment_variable_flags+=(--var "$var")
done

bash_interactive="$(nix eval --raw --file nix/packages.nix 'bashInteractive')/bin/bash"

mise run debug:make-isolated-env \
  "${environment_variable_flags[@]}" \
  -- \
  --file nix/packages.nix nix \
  --command nix-shell direnv/direnv-wrapper.bash direnv/config/ci.bash exec . "$bash_interactive" --noprofile --norc
