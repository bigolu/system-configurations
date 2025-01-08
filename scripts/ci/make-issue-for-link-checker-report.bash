#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter gh]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

gh issue create --title 'Link Checker Report' --body-file ./lychee/out.md
