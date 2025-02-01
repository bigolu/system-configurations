#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i bash
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter]"
#MISE description="Display task documentation"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

function main {
  local -r documentation='docs/tasks.html'

  local opener
  opener="$(get_opener)"
  if [[ -z $opener ]]; then
    echo "Unable to find a command for opening the documentation so you'll have to open it yourself. Path to documentation: $documentation" >&2
    exit 1
  fi

  "$opener" "$documentation"
}

# Print path to opener or nothing if one can't be found
function get_opener {
  # Linux uses xdg-open, macOS uses open
  local -ra candidates=(xdg-open open)
  local candidate
  for candidate in "${candidates[@]}"; do
    if type -P "$candidate"; then
      return
    fi
  done
}

main
