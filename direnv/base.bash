# shellcheck shell=bash

# This script sets up the direnv environment that is used in local development
# and CI. It's called "base" since there are also scripts specific to the local
# and CI environment that source this one.
#
# Environment Variables
#   NIX_DEV_SHELL (required):
#     The name of the flake dev shell to load.

function main {
  # This should run first. The reason for this is in a comment at the top of
  # `direnv-manual-reload.bash`.
  source direnv/direnv-manual-reload.bash
  direnv_manual_reload

  # Now I don't need to add checks everywhere to create this directory if it doesn't
  # exist.
  create_direnv_layout_dir
  dotenv_if_exists secrets.env
  set_up_nix
}

function create_direnv_layout_dir {
  local layout_dir
  layout_dir="$(direnv_layout_dir)"

  mkdir -p "$layout_dir"

  local -r gitignore_path="${layout_dir}/.gitignore"
  if [[ ! -e $gitignore_path ]]; then
    echo '*' >"$gitignore_path"
  fi
}

function set_up_nix {
  load_nix_config_file "${PWD}/nix/nix.conf"

  # renovate: nix-direnv
  source_url \
    'https://raw.githubusercontent.com/nix-community/nix-direnv/3.0.6/direnvrc' \
    'sha256-RYcUJaRMf8oF5LznDrlCXbkOQrywm0HDv1VjYGaJGdM='
  use flake ".#${NIX_DEV_SHELL:?}"
}

function load_nix_config_file {
  local -r config_file="$1"
  export NIX_CONFIG="${NIX_CONFIG:+$NIX_CONFIG$'\n'}include ${config_file}"
}

main
