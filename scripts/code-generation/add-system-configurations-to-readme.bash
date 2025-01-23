#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter perl]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

function main {
  configs="$(
    nix eval --raw --file nix/system-configurations-as-markdown.nix
    # Add a character to the end of the output to preserve trailing newlines.
    printf x
  )"
  configs="${configs::-1}"

  perl -0777 -w -i -pe \
    "s{(<!-- START_CONFIGURATIONS -->).*(<!-- END_CONFIGURATIONS -->)}{\$1$configs\$2}igs" \
    README.md
}

main
