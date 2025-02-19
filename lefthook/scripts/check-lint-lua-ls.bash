#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter lua-language-server jq]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

log_path="${DIRENV_LAYOUT_DIR:?}/lua-ls-logs"

# --configpath is relative to the directory being checked
# so I'm using an absolute path instead.
lua-language-server \
  --logpath "$log_path" \
  --check ./dotfiles/neovim \
  --configpath "$PWD/.luarc.json"

check_file="${log_path}/check.json"
# The file will contain '[]' when there are no errors
if [[ $(<"$check_file") != '[]' ]]; then
  jq --raw-output '
    to_entries[] |
    .key as $file |
    .value[] |
    "\($file):\(.range.start.line):\(.range.start.character): \(.message)"
  ' "$check_file"
  exit 1
fi
