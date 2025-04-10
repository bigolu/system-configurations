#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter coreutils]"
#MISE description="Start a Bash shell in a direnv CI environment"
#USAGE arg "<direnv_dev_shell>" help="The dev shell that direnv should load"
#USAGE complete "direnv_dev_shell" run=#"""
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

direnv_layout_dir="$(mktemp --directory)"
home="$(mktemp --directory)"
environment_variables=(
  DIRENV_DEV_SHELL="${usage_direnv_dev_shell:?}"
  CI_DEBUG=true

  # direnv stores its cache in the directory specified in `direnv_layout_dir`.
  # If it's not set, .direnv is used. I'm changing it so nix-direnv doesn't
  # overwrite the dev shell cached in .direnv with the one built here.
  direnv_layout_dir="$direnv_layout_dir"

  # direnv requires the `HOME` variable be set. I'm using a temporary
  # directory to avoid accessing anything from the real `HOME` inside this
  # environment.
  HOME="$home"
)
environment_variable_flags=()
for var in "${environment_variables[@]}"; do
  environment_variable_flags+=(--var "$var")
done

bash_interactive="$(nix eval --raw --file nix/flake-package-set.nix 'bashInteractive')/bin/bash"

mise run debug:make-isolated-env \
  "${environment_variable_flags[@]}" \
  -- \
  --file nix/flake-package-set.nix nix \
  --command nix-shell direnv/direnv-wrapper.bash direnv/ci.bash exec . "$bash_interactive" --noprofile --norc
