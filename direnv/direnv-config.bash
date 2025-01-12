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
  #   - Reloading nix-direnv takes a while (~30 seconds on my machine) so I'd like
  #     more control over when that happens.
  #
  # This should run first, see the comment above the function for why.
  disable_direnv_auto_reload

  dotenv_if_exists secrets.env
  set_up_nix
  # Sets GOPATH and GOBIN and adds GOBIN to the PATH
  layout go

  if ! is_first_direnv_load; then
    log_status '[tip] Remember to reload direnv inside your editor as well.'
  fi
}

# nix-direnv will refresh its cache whenever a file watched by direnv changes.
# However, it only considers files that were on the watch list _before_ the call to
# `use flake`. To get around this, I'm adding the reload file to the watch list
# now.
function disable_direnv_auto_reload {
  DIRENV_RELOAD_FILE="$(create_direnv_reload_file)"
  watch_file "$DIRENV_RELOAD_FILE"
  # Export it so we can access it from `sync-direnv.bash`.
  export DIRENV_RELOAD_FILE
  prepend_to_exit_trap "$(printf 'remove_watched_files_within_project %q' "$DIRENV_RELOAD_FILE")"
}

function create_direnv_reload_file {
  direnv_layout_dir="$(direnv_layout_dir)"
  if [[ ! -e $direnv_layout_dir ]]; then
    mkdir "$direnv_layout_dir"
  fi

  reload_file="$direnv_layout_dir/reload"
  if [[ ! -e $reload_file ]]; then
    touch "$reload_file"
  fi

  echo "$reload_file"
}

# Disable direnv's auto reloading by removing all of the files in this project from
# its watch list, except our reload file.
#
# This should be run last to prevent files from being added to the watch list after
# it runs.
function remove_watched_files_within_project {
  local -r reload_file="$1"

  readarray -d '' watched_files < <(direnv watch-print --null)

  # Keep the watched files that are outside of the project directory so direnv
  # reloads after `direnv allow/block`.
  watched_files_to_keep=()
  for file in "${watched_files[@]}"; do
    if [[ $file != "$PWD"* || $file == "$reload_file" ]]; then
      watched_files_to_keep+=("$file")
    fi
  done

  unset DIRENV_WATCHES
  watch_file "${watched_files_to_keep[@]}"
}

# direnv sets an exit trap so we should prepend ours to it instead of overwriting it
function prepend_to_exit_trap {
  local -r new_trap_handler="$1"

  eval "local -ra tokens=($(trap -p EXIT))"
  # shellcheck disable=2154
  # I declare `tokens` in the eval statement above
  local -r old_trap_handler="${tokens[2]}"

  trap -- "$new_trap_handler"$'\n'"$old_trap_handler" EXIT
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

function is_first_direnv_load {
  # This variable gets set by direnv so it won't be set on the first load.
  ! is_set DIRENV_DIFF
}

function is_setting_up_ci_environment {
  # Most CI systems, e.g. GitHub Actions, set this variable to 'true'.
  is_set CI && [[ $CI == 'true' ]]
}

function is_setting_up_local_environment {
  ! is_setting_up_ci_environment
}

function is_set {
  local -r variable_name="$1"
  [[ -n ${!variable_name+x} ]]
}

main
