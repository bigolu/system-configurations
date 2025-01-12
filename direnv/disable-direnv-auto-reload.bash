# shellcheck shell=bash

# nix-direnv will refresh its cache whenever a file watched by direnv changes.
# However, it only considers files that were on the watch list _before_ the call to
# `use flake`. To get around this, I'm adding the reload file to the watch list
# now.
function main {
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

main
