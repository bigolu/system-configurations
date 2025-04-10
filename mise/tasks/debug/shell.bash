#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter coreutils]"
#MISE description="Start `.#shell` in an empty environment"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

home="$(mktemp --directory)"

# Use '*' so I don't have to hard code the program name
shell_path=("$(nix build --print-out-paths --no-link .#shell)/bin/"*)

mise run debug:make-isolated-env \
  --var HOME="$home" \
  -- \
  --command "${shell_path[@]}"
