#! /usr/bin/env cached-nix-shell
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter ast-grep jq coreutils gnused

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

# shellcheck disable=SC2016
# The dollar signs are for ast-grep
ast-grep --lang lua --pattern 'Plug($ARG $$$)' --json=compact ./dotfiles/neovim/lua \
  | jq --raw-output '.[].metaVariables.single.ARG.text' \
  | cut -d'/' -f2 \
  | sed 's/.$//' \
  | sort --ignore-case --dictionary-order --unique \
    >./dotfiles/neovim/plugin-names.txt
