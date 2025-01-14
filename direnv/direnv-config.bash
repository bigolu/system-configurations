# shellcheck shell=bash

# This script sets up the local development or CI environment. It should be sourced
# from the .envrc.
#
# Environment Variables
#   DEV_SHELL:
#     The name of the flake dev shell to load. If it isn't set, then a default
#     will be used. The default is "local" if the local environment is being set
#     up and "ci-default" if the CI environment is being set up.
#   CI:
#     If set to "true", the environment will be set up for CI. Otherwise, the local
#     development environment will be set up.

function main {
  # For the reasons why I want to manually reload direnv, see the comment at the top
  # of `direnv-manual-reload.bash`.
  #
  # This should run first. The reason for this is in a comment at the top of
  # `direnv-manual-reload.bash`.
  source ./direnv/direnv-manual-reload.bash

  dotenv_if_exists secrets.env
  set_up_nix
  # Sets GOPATH and GOBIN and adds GOBIN to the PATH
  layout go
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
  local -r setting_to_add="include ${config_file}"

  if ! is_set NIX_CONFIG; then
    export NIX_CONFIG="$setting_to_add"
  else
    NIX_CONFIG+=$'\n'"$setting_to_add"
  fi
}

function load_dev_shell {
  source_url \
    'https://raw.githubusercontent.com/nix-community/nix-direnv/3.0.6/direnvrc' \
    'sha256-RYcUJaRMf8oF5LznDrlCXbkOQrywm0HDv1VjYGaJGdM='
  # I want the first dev shell build to happen automatically and all subsequent ones
  # to be done manually. I'm doing this because building a dev shell can take a while
  # (~30 seconds on my machine) so I want to control when it happens.
  if has_cached_dev_shell; then
    nix_direnv_manual_reload
  fi
  use flake ".#$(get_dev_shell)"
}

function has_cached_dev_shell {
  # nix-direnv makes a few files in the form 'flake-profile-*' after caching a dev
  # shell so we'll assume a dev shell has been cached if those files exist.
  #
  # By default, if there are no matches for a glob, Bash prints the glob itself. I'm
  # disabling this behavior with shopt, but doing it in a subshell so it doesn't
  # apply to the rest of the script.
  [[ -n "$(
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
    echo 'ci-default'
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
