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
  local -r directory="${direnv_layout_dir:-.direnv}"
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

  # Even when a dev shell is cached nix-direnv is a bit slow so I'm doing my own
  # caching.
  local -r last_reload_time_file="${direnv_layout_dir:-.direnv}/last-reload-time"
  local -r reload_file="${direnv_layout_dir:-.direnv}/reload"
  local reload_file_last_modified_time
  reload_file_last_modified_time="$(stat --format=%Y "$reload_file")"
  local dev_shell_setup_script
  dev_shell_setup_script="$(
    # By default, if there are no matches for a glob, Bash prints the glob itself. I
    # don't want anything to be printed if there's no match so I'm disabling this
    # behavior. I'm doing so in a subshell so it doesn't apply to the rest of the
    # script.
    shopt -s nullglob
    echo "${direnv_layout_dir:-.direnv}/flake-profile-"*.rc
  )"
  if
    [[ -e $dev_shell_setup_script ]] &&
      [[ -e $last_reload_time_file ]] &&
      (($(<"$last_reload_time_file") == reload_file_last_modified_time))
  then
    # shellcheck disable=1090
    source "$dev_shell_setup_script"
  else
    # renovate: nix-direnv
    source_url \
      'https://raw.githubusercontent.com/nix-community/nix-direnv/3.0.7/direnvrc' \
      'sha256-bn8WANE5a91RusFmRI7kS751ApelG02nMcwRekC/qzc='
    use flake ".#${NIX_DEV_SHELL:?}"
    echo "$reload_file_last_modified_time" >"$last_reload_time_file"
  fi
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
