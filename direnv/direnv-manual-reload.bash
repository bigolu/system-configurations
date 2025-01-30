# shellcheck shell=bash

# This script will disable direnv's automatic reloading. It will still automatically
# load when you first enter the directory, but it will not reload after that. If you
# want to reload the environment, you can instead use the command `direnv-reload`
# which will be added to the PATH. If you use this script, `direnv reload` will no
# longer work, you have to use `direnv-reload`.
#
# Usage:
#   Add the following two lines to the top of your envrc:
#     source <path_to_this_script>
#     direnv_manual_reload
#   Why it should be at the top:
#     nix-direnv[1] will only refresh its cache when a file watched by direnv
#     changes. However, it only considers files that were on the watch list _before_
#     the call to `use nix/flake`[2]. This means the reload file that gets created
#     here needs to be on the watch list before calling `use nix/flake`.
#
# Reasons why you may want to do this:
#   - You may not want direnv to reload when a watched file changes. Like when using
#     `git checkout` or `git rebase --interactive` for example.
#   - If reloading your .envrc takes a while, you may want more control over when
#     that happens. For example, without manual reload, direnv will reload whenever a
#     watched file's modification time changes, even if the contents are the same.
#   - Manual reloading can help avoid excessive direnv reloads when using auto save
#     and a file watcher. For example, if you use the editor extension direnv-vscode,
#     or something similar, then you have the option to have it automatically reload
#     whenever one of the files in direnv's watch list changes. This is a convenient
#     way to keep your terminal and editor's direnv environments in sync. However, if
#     you also use auto save, then direnv-vscode will reload every time you type a
#     character into any of the files on the watch list. This could make vscode lag
#     since direnv-vscode also reloads all of the other extensions, so they can pick
#     up the new environment as well. If you use this script, then the only watched
#     file will be the one created by the script. Since you never edit that file, you
#     won't trigger any reloads. Instead, you can reload both your terminal and
#     editor's direnv environment by running `direnv-reload`.
#
# How it works:
#   - direnv automatically reloads whenever it detects a change in the modification
#     time of any of the files on its watch list. To stop it from doing so, this
#     script removes all files from the watch list except the following ones:
#       - reload file: To give users a way to manually reload direnv, a new file is
#         created and put on the watch list, `.direnv/reload`. A command named
#         `direnv-reload` is put on the PATH which will change the modification time
#         of that file, causing direnv to reload.
#       - allow/deny files: We keep those files on the watch list so
#         `direnv allow/block` still triggers a reload.
#
# [1]: https://github.com/nix-community/nix-direnv
# [2]: https://github.com/nix-community/nix-direnv?tab=readme-ov-file#tracked-files
# [3]: https://github.com/direnv/direnv-vscode

function direnv_manual_reload {
  local reload_file
  reload_file="$(create_reload_file)"

  watch_file "$reload_file"
  add_reload_program_to_path "$reload_file"
  run_before_exit "$(printf 'remove_watched_files %q' "$reload_file")"
}

function add_reload_program_to_path {
  local -r reload_file="$1"

  local reload_program
  reload_program="$(get_direnv_bin)/direnv-reload"
  {
    echo '#!/usr/bin/env bash'
    printf 'touch %q\n' "$reload_file"
  } >"${reload_program}"
  chmod +x "${reload_program}"
}

function create_reload_file {
  direnv_dir="$(get_direnv_dir)"
  reload_file="$direnv_dir/reload"
  if [[ ! -e $reload_file ]]; then
    touch "$reload_file"
  fi

  echo "$reload_file"
}

function get_direnv_bin {
  direnv_bin="$(get_direnv_dir)/bin"
  if [[ ! -e $direnv_bin ]]; then
    mkdir "$direnv_bin"
  fi

  # First try removing it so we don't add a duplicate entry to the PATH
  PATH_rm "$direnv_bin"
  PATH_add "$direnv_bin"

  echo "$direnv_bin"
}

function get_direnv_dir {
  layout_dir="$(direnv_layout_dir)"
  if [[ ! -e $layout_dir ]]; then
    mkdir "$layout_dir"
  fi
  echo "$layout_dir"
}

function remove_watched_files {
  local -r reload_file="$1"

  # shellcheck disable=2312
  # TODO: The exit code of direnv is being masked by readarray, but it would be
  # tricky to avoid that. I can't use a pipeline since I want to unset the
  # DIRENV_WATCHES environment variable below. I could put the output of the direnv
  # command in a temporary file, but since this runs every time you enter the project
  # directory I want to avoid doing anything slow.
  readarray -d '' watched_files < <(direnv watch-print --null)

  # Keep our reload file and direnv's allow/deny files, so `direnv block/allow` still
  # triggers a reload.
  watched_files_to_keep=()
  direnv_data_directory="${XDG_DATA_HOME:-$HOME/.local/share}/direnv"
  for file in "${watched_files[@]}"; do
    case "$file" in
      "$direnv_data_directory/deny"*) ;&
      "$direnv_data_directory/allow"*) ;&
      "$reload_file")
        watched_files_to_keep+=("$file")
        ;;
    esac
  done

  unset DIRENV_WATCHES
  watch_file "${watched_files_to_keep[@]}"
}

function run_before_exit {
  local -r command_to_run="$1"

  # direnv sets an exit trap so we should prepend ours to it instead of overwriting
  # it.
  local current_trap_handler
  current_trap_handler="$(get_exit_trap_handler)"
  trap -- "$command_to_run"$'\n'"$current_trap_handler" EXIT
}

function get_exit_trap_handler {
  # `trap -p EXIT` will print 'trap -- <old_handler> EXIT'. The output seems to be
  # formatted the way the %q directive for printf formats variables[1]. Because of
  # this, we can use eval to tokenize it.
  #
  # [1]: https://www.gnu.org/software/coreutils/manual/html_node/printf-invocation.html#printf-invocation
  local trap_output
  trap_output="$(trap -p EXIT)"
  eval "local -ra trap_output_tokens=($trap_output)"
  # shellcheck disable=2154
  # I declare `trap_output_tokens` in the eval statement above
  echo "${trap_output_tokens[2]}"
}
