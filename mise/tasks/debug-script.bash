#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter ripgrep]"
#MISE description="Enter a nix shell with a script's dependencies"
#USAGE arg "<script>" help="The path to the script"
#USAGE complete "script" run=#"fd --extension 'bash' --glob '*' scripts mise/tasks"#

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# Mise sets these variables, but we're doing this so shellcheck doesn't warn us that
# they may be unset: https://www.shellcheck.net/wiki/SC2154
declare usage_script

readarray -t dependencies < <(
  # Extract the script's dependencies from its nix-shell shebang.
  #
  # The shebang looks something like:
  #   #! nix-shell --packages "with ...; [dep1 dep2 dep3]"
  #
  # This command will extract everything between the brackets i.e.
  #   'dep1 dep2 dep3'.
  rg \
    --no-filename \
    --glob '*.bash' \
    '^#! nix-shell (--packages|-p) .*\[(?P<packages>.*)\].*' \
    --replace '$packages' \
    "$usage_script" \
    |
    # This command matches 1 or more consecutive characters that aren't spaces
    # so it will print each dependency on a different line.
    rg --only-matching '[^ ]+'
)

nix shell --impure --expr 'import ./nix/flake-package-set.nix' "${dependencies[@]}"
