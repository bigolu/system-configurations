#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter perl]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

configs="$(nix eval --raw --file nix/config-names.nix)"

perl -0777 -w -s -i -pe \
  's{(system-init <).*?(>)}{$1$configs$2}igs' \
  -- -configs="$configs" \
  README.md
