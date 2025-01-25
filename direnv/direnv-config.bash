# shellcheck shell=bash

# This script sets up the local development or CI environment. It should be sourced
# from the .envrc.
#
# Environment Variables
#   DEV_SHELL:
#     The name of the flake dev shell to load. If it isn't set, then a default
#     will be used. The default is "local" if the local environment is being set
#     up and "ci-essentials" if the CI environment is being set up.
#   CI:
#     If set to "true", the environment will be set up for CI. Otherwise, the local
#     development environment will be set up.

function main {
  # This should run first. The reason for this is in a comment at the top of
  # `direnv-manual-reload.bash`.
  enable_manual_reload
  create_layout_dir
  dotenv_if_exists secrets.env
  set_cache_locations
  set_up_nix
}

function enable_manual_reload {
  source direnv/direnv-manual-reload.bash
  direnv_manual_reload
}

function create_layout_dir {
  local layout_dir
  layout_dir="$(direnv_layout_dir)"

  # Now I don't need to add checks everywhere to create this directory if it doesn't
  # exist.
  mkdir -p "$layout_dir"
  # So any tools called here, like nix, can also store their things in the layout
  # dir.
  export DIRENV_LAYOUT_DIR="$layout_dir"
}

function set_cache_locations {
  export PYTHONPYCACHEPREFIX="$DIRENV_LAYOUT_DIR/python-cache"
  export MYPY_CACHE_DIR="$DIRENV_LAYOUT_DIR/mypy-cache"
  export RUFF_CACHE_DIR="$DIRENV_LAYOUT_DIR/ruff-cache"
}

function set_up_nix {
  set_nix_config
  load_dev_shell
}

function set_nix_config {
  local -r nix_config_directory="${PWD}/nix/config"

  include_nix_config_file "${nix_config_directory}/common.conf"
  if is_setting_up_ci_environment; then
    include_nix_config_file "${nix_config_directory}/ci.conf"
  fi
}

function include_nix_config_file {
  local -r config_file="$1"
  export NIX_CONFIG="${NIX_CONFIG:+$NIX_CONFIG$'\n'}include ${config_file}"
}

function load_dev_shell {
  source_url \
    'https://raw.githubusercontent.com/nix-community/nix-direnv/3.0.6/direnvrc' \
    'sha256-RYcUJaRMf8oF5LznDrlCXbkOQrywm0HDv1VjYGaJGdM='

  # I want the first dev shell build to happen automatically and all subsequent
  # ones to be done manually. I'm doing this because building a dev shell can take
  # a while (~30 seconds on my machine) so I want to control when it's rebuilt.
  if ! is_first_dev_shell_build; then
    nix_direnv_manual_reload
  fi

  use flake ".#$(get_dev_shell)"
}

function is_first_dev_shell_build {
  # nix-direnv makes a few files in the form 'flake-profile-*' after building a dev
  # shell. We'll assume this is the first build if those files don't exist.
  [[ -z "$(
    # By default, if there are no matches for a glob, Bash prints the glob itself. I
    # don't want anything to be printed if there's no match so I'm disabling this
    # behavior. I'm doing so in a subshell so it doesn't apply to the rest of the
    # script.
    shopt -s nullglob
    echo "$(direnv_layout_dir)/flake-profile-"*
  )" ]]
}

function get_dev_shell {
  if is_set DEV_SHELL; then
    echo "$DEV_SHELL"
  else
    get_default_dev_shell
  fi
}

function get_default_dev_shell {
  if is_setting_up_ci_environment; then
    echo 'ci-essentials'
  else
    echo 'local'
  fi
}

function is_setting_up_ci_environment {
  # Most CI systems, e.g. GitHub Actions, set this variable to 'true'.
  is_set CI && [[ $CI == 'true' ]]
}

function is_set {
  local -r variable_name="$1"
  [[ -n ${!variable_name+x} ]]
}

main
