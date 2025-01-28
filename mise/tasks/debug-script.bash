#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter ripgrep]"
#MISE description="Enter a nix shell with a script's dependencies"
#USAGE arg "<script>" help="The path to the script"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

# Mise sets these variables, but we're doing this so shellcheck doesn't warn us that
# they may be unset: https://www.shellcheck.net/wiki/SC2154
declare usage_script

readarray -t dependencies < <(
  # Extract the script's dependencies from its nix-shell shebang.
  #
  # The shebang looks something like:
  #   #! nix-shell --packages "with ...; [dep1 dep2 dep3]"
  #
  # So this command will extract everything between the brackets i.e.
  #   'dep1 dep2 dep3'.
  #
  # Each line printed will contain the extraction above, per script.
  rg \
    --no-filename \
    --glob '*.bash' \
    '^#! nix-shell (--packages|-p) .*\[(?P<packages>.*)\].*' \
    --replace '$packages' \
    "$usage_script" \
    |
    # Flatten the output of the previous command i.e. print _one_ dependency per line
    rg --only-matching '[^\s]+'
)

nix shell --impure --expr 'import ./nix/flake-package-set.nix' "${dependencies[@]}"
