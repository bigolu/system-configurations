set -euo pipefail

readarray -t config_files \
  < <(find ./dotfiles/neovim/lua -type f -name '*.lua')
# shellcheck disable=SC2016
# The dollar signs are for ast-grep
sg --lang lua --pattern 'Plug($ARG $$$)' --json=compact "${config_files[@]}" |
  jq --raw-output '.[].metaVariables.single.ARG.text' |
  cut -d'/' -f2 |
  sed 's/.$//' |
  sort --ignore-case --dictionary-order --unique \
    >./dotfiles/neovim/plugin-names.txt
