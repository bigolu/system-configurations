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
  # Why I want to disable direnv's auto reload:
  #   - It reloads whenever a watched file's modification time changes, even if the
  #     contents are the same.
  #   - Sometimes a watched file changes, but I don't want to reload. Like when doing
  #     a git checkout or interactive rebase.
  #   - Reloading nix-direnv takes a while (~30 seconds on my machine) so I'd like to
  #     control when that happens.
  #   - I want my editor's direnv extension (vscode-direnv) to automatically reload
  #     whenever I reload direnv in the terminal. vscode-direnv has an option for
  #     reloading whenever one of direnv's watched files changes, but since I use
  #     auto save, this would trigger a reload everytime I type a character into one
  #     of direnv's watched files. This would make vscode lag since vscode-direnv
  #     also reloads all of my other extensions, so they can pick up the new
  #     environment. As part of disabling auto reload, the script below will set
  #     direnv's watch list to a single file, .direnv/reload. This file will be
  #     updated when I run `direnv-reload`. This means a call to `direnv-reload` from
  #     the terminal will reload direnv in both the terminal and the editor.
  #
  # This should run first. The reason for this is in a comment at the top of the file
  # being sourced below.
  source ./direnv/disable-direnv-auto-reload.bash

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
  use flake ".#$(get_dev_shell)"
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
