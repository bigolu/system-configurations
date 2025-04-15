#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep FLAKE_INTERNAL_PACKAGE_SET
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_INTERNAL_PACKAGE_SET\")); [nix-shell-interpreter coreutils]"
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
