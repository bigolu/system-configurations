# Environment Variables
#   NIX_DEV_SHELL (required):
#     The name of the flake dev shell to load.

function main {
  # This should run first. The reason for this is in a comment at the top of
  # `direnv-manual-reload.bash`.
  source direnv/direnv-manual-reload.bash
  direnv_manual_reload

  direnv_init_layout_directory
  dotenv_if_exists secrets.env
  set_up_nix
}

function direnv_init_layout_directory {
  local -r layout_directory="${direnv_layout_dir:-.direnv}"

  local -r init_complete_marker="$layout_directory/direnv-layout-dir-initialized"
  if [[ -e $init_complete_marker ]]; then
    return
  fi

  mkdir -p "$layout_directory"
  add_directory_to_gitignore "$layout_directory"

  touch "$init_complete_marker"
}

function add_directory_to_gitignore {
  local -r directory="$1"
  echo '*' >"${directory}/.gitignore"
}

function set_up_nix {
  load_nix_config_file "${PWD}/nix/nix.conf"

  # renovate: nix-direnv
  source_url \
    'https://raw.githubusercontent.com/nix-community/nix-direnv/3.0.7/direnvrc' \
    'sha256-bn8WANE5a91RusFmRI7kS751ApelG02nMcwRekC/qzc='
  use flake ".#${NIX_DEV_SHELL:?}"
}

# TODO: This wouldn't be necessary if nix supported project/directory-specific config
# files[1]. The `nixConfig` field on a flake isn't a good alternative because it only
# supports flakes so it doesn't apply to nix shebang scripts for example.
#
# https://github.com/NixOS/nix/issues/10258
function load_nix_config_file {
  local -r config_file="$1"
  add_line_to_nix_config "include ${config_file}"
}

function add_line_to_nix_config {
  local -r line="$1"

  if [[ -z ${NIX_CONFIG:-} ]]; then
    new_config="$line"
  else
    new_config="$NIX_CONFIG"$'\n'"$line"
  fi

  export NIX_CONFIG="$new_config"
}

main
