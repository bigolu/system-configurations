#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep FLAKE_INTERNAL_PACKAGE_SET
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_INTERNAL_PACKAGE_SET\")); [nix-shell-interpreter coreutils]"
#MISE description="Start a Bash shell in a direnv CI environment"
#USAGE arg "<nix_dev_shell>" help="The dev shell that direnv should load"
#USAGE complete "nix_dev_shell" run=#"""
#USAGE   nix eval --impure --raw --apply \
#USAGE     '
#USAGE       with builtins;
#USAGE       shells:
#USAGE         concatStringsSep
#USAGE           "\n"
#USAGE           (filter
#USAGE             (name: (substring 0 3 name) == "ci-")
#USAGE             (attrNames shells))
#USAGE     ' \
#USAGE     .#currentSystem.devShells 2>/dev/null
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

  # direnv stores its cache in the directory specified in `direnv_layout_dir`.
  # If it's not set, .direnv is used. I'm changing it so nix-direnv doesn't
  # overwrite the dev shell cached in .direnv with the one built here.
  direnv_layout_dir="$(mktemp --directory)"
)
environment_variable_flags=()
for var in "${environment_variables[@]}"; do
  environment_variable_flags+=(--var "$var")
done

bash_interactive="$(nix eval --raw --file nix/flake/internal-package-set.nix 'bashInteractive')/bin/bash"

mise run debug:make-isolated-env \
  "${environment_variable_flags[@]}" \
  -- \
  --file nix/flake/internal-package-set.nix nix \
  --command nix-shell direnv/direnv-wrapper.bash direnv/ci.bash exec . "$bash_interactive" --noprofile --norc
