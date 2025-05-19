# This script sets up the direnv environment that is used in development
# and CI. It's called "base" since there are also scripts specific to the
# development and CI environment that source this one.
#
# Environment Variables
#   NIX_DEV_SHELL (required):
#     The name of the flake dev shell to load.

function main {
  # This should run first. The reason for this is in a comment at the top of
  # `direnv-manual-reload.bash`.
  source direnv/direnv-manual-reload.bash
  direnv_manual_reload

  # Now I can store things in the layout directory without having to check if it
  # exists first.
  create_direnv_layout_directory

  dotenv_if_exists secrets.env
  set_up_nix
}

function create_direnv_layout_directory {
  local directory
  directory="$(direnv_layout_dir)"

  if [[ ! -e $directory ]]; then
    mkdir "$directory"
  fi
  add_directory_to_gitignore "$directory"
}

function add_directory_to_gitignore {
  local -r directory="$1"

  local -r gitignore="${directory}/.gitignore"
  if [[ ! -e $gitignore ]]; then
    echo '*' >"$gitignore"
  fi
}

function set_up_nix {
  load_nix_config_file "${PWD}/nix/nix.conf"

  # renovate: nix-direnv
  source_url \
    'https://raw.githubusercontent.com/nix-community/nix-direnv/3.0.7/direnvrc' \
    'sha256-bn8WANE5a91RusFmRI7kS751ApelG02nMcwRekC/qzc='
  use flake ".#${NIX_DEV_SHELL:?}"
}

function load_nix_config_file {
  local -r config_file="$1"
  add_line_to_nix_config "include ${config_file}"
}

function add_line_to_nix_config {
  local -r line="$1"

  if [[ -z ${NIX_CONFIG+set} ]]; then
    export NIX_CONFIG=''
  fi

  if [[ -z $NIX_CONFIG ]]; then
    NIX_CONFIG="$line"
  else
    NIX_CONFIG+=$'\n'"$line"
  fi
}

main
