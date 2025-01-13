# shellcheck shell=bash

# nix-direnv will refresh its cache whenever a file watched by direnv changes.
# However, it only considers files that were on the watch list _before_ the call to
# `use flake`. To get around this, I'm adding the reload file to the watch list
# now.
function main {
  local -r direnv_reload_file="$(create_direnv_reload_file)"

  watch_file "$direnv_reload_file"
  add_reload_program_to_path "$direnv_reload_file"
  prepend_to_exit_trap "$(printf 'remove_watched_files_within_project %q' "$direnv_reload_file")"
}

function add_reload_program_to_path {
  local -r direnv_reload_file="$1"

  direnv_bin="$(get_direnv_dir)/bin"
  if [[ ! -e $direnv_bin ]]; then
    mkdir "$direnv_bin"
  fi
  # First try removing it so we don't add a duplicate entry to the PATH
  PATH_rm "$direnv_bin"
  PATH_add "$direnv_bin"

  # nix-direnv will only reload the dev shell if its cache is invalid. nix-direnv
  # only considers its cache invalid when one of the files tracked by direnv changes.
  # To force it to reload, I'm changing our designated reload file.
  #
  # `direnv reload` touches a file tracked by direnv to make it reload at the next
  # shell prompt. To force it to reload now, so I can pipe the output to `nom`, I'm
  # using `direnv exec` with a command that won't do anything, `true`.
  {
    echo '#!/usr/bin/env bash'
    printf 'touch %q\n' "$direnv_reload_file"
  } >"${direnv_bin}/direnv-reload"
  chmod +x "${direnv_bin}/direnv-reload"
}

function create_direnv_reload_file {
  direnv_dir="$(get_direnv_dir)"
  reload_file="$direnv_dir/reload"
  if [[ ! -e $reload_file ]]; then
    touch "$reload_file"
  fi

  echo "$reload_file"
}

function get_direnv_dir {
  layout_dir="$(direnv_layout_dir)"
  if [[ ! -e $layout_dir ]]; then
    mkdir "$layout_dir"
  fi
  echo "$layout_dir"
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

main
