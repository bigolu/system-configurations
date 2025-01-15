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

# direnv's stdlib will be sourced before this file is executed so I want to make
# _shellcheck aware of this so we can get autocomplete, go to definition, etc. To do
# so, I'm going to pretend to source direnv's stdlib here. This way, I can use a
# _shellcheck directive to give it the location of direnv's stdlib.
#
# If a shellcheck directive is placed before the first command in the file, it gets
# applied to the entire script[1]. To avoid that, I added a command here.
#
# I put an '_' before any line that starts with 'shellcheck' because shellcheck was
# mistaking it for a directive.
#
# [1]: https://github.com/koalaman/shellcheck/blob/d3001f337aa3f7653a621b302261f4eac01890d0/shellcheck.1.md#directives
:
# shellcheck source=./.direnv/stdlib.bash
source <(:)

function main {
  # This should run first. The reason for this is in a comment at the top of
  # `direnv-manual-reload.bash`.
  enable_direnv_manual_reload
  dotenv_if_exists secrets.env
  set_up_nix
  layout go
}

# Reasons why you may want to enable manual reloading can be found in a comment at
# the top of `direnv-manual-reload.bash`.
function enable_direnv_manual_reload {
  source direnv/direnv-manual-reload.bash
  direnv_manual_reload
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
  # (~30 seconds on my machine) so I want to control when it's rebuilt.
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
