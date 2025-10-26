# Disable direnv's automatic reloading. It will still automatically load when you
# first enter the directory, but it will not reload after that. If you want to reload
# the environment, you can instead use the command `direnv-reload` which will be
# added to the PATH. If you use this script, `direnv reload` will no longer work, you
# have to use `direnv-reload`.
#
# Usage:
#   Add the following two lines to the top of your envrc:
#     source <path_to_this_script>
#     direnv_manual_reload
#   Why it should be at the top:
#     - nix-direnv[1] will only refresh its cache when a file watched by direnv
#       changes. However, it only considers files that were on the watch list
#       _before_ the call to `use nix/flake`[2]. This means the reload file that
#       gets created here needs to be on the watch list before calling `use
#       nix/flake`.
#     - nix-direnv[1] adds files to the watch list. To prevent that, this script
#       overrides the `watch_file` function from the direnv stdlib with a no-op
#       function.
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
  local layout_dir
  layout_dir="$(_dmr_make_layout_dir)"

  local reload_file
  reload_file="$(_dmr_make_reload_file "$layout_dir")"

  _dmr_set_watch_list "$reload_file"
  _dmr_disable_file_watching
  _dmr_add_reload_program_to_path "$layout_dir" "$reload_file"
}

function _dmr_make_layout_dir {
  local layout_dir
  layout_dir="$(direnv_layout_dir)"

  if [[ ! -e $layout_dir ]]; then
    mkdir -p "$layout_dir"
  fi

  echo "$layout_dir"
}

function _dmr_make_reload_file {
  local -r layout_dir="$1"

  local -r reload_file="$layout_dir/reload"
  if [[ ! -e $reload_file ]]; then
    # Create a file without using an external command
    true >"$reload_file"
  fi

  echo "$reload_file"
}

function _dmr_set_watch_list {
  local -r reload_file="$1"

  local -a watched_files
  shopt -s lastpipe
  # shellcheck disable=2312
  # pipefail will be enabled when direnv runs
  direnv watch-print --null | { readarray -d '' watched_files; }
  shopt -u lastpipe

  local -a allow_and_deny_files
  local file
  for file in "${watched_files[@]}"; do
    if [[ $file =~ "${XDG_DATA_HOME:-$HOME/.local/share}/direnv/"('allow'|'deny')'/'* ]]; then
      allow_and_deny_files+=("$file")
    fi
  done

  unset DIRENV_WATCHES
  # Keep the allow/deny files, so `direnv allow/deny` still triggers a reload.
  watch_file "${allow_and_deny_files[@]}" "$reload_file"
}

function _dmr_disable_file_watching {
  # Override the watch functions from the direnv stdlib with no-ops.
  #
  # TODO: While these are the only public APIs for modifying the watch list, users
  # could still mutate the DIRENV_WATCHES environment variable directly or call the
  # private subcommands in direnv for manipulating the watch list e.g. `direnv
  # (watch|watch-list|watch-dir)`. We could account for that by using an exit trap
  # that sets the watch list. Maybe we should do that instead of disabling these
  # functions.
  #
  # shellcheck disable=2329
  function watch_file {
    :
  }
  # shellcheck disable=2329
  function watch_dir {
    :
  }
}

function _dmr_add_reload_program_to_path {
  local -r layout_dir="$1"
  local -r reload_file="$2"

  local -r direnv_bin="$layout_dir/bin"
  if [[ ! -e $direnv_bin ]]; then
    mkdir "$direnv_bin"
  fi
  # Ensure we don't add the same directory to the PATH twice.
  PATH_rm "$direnv_bin"
  PATH_add "$direnv_bin"

  local reload_program
  reload_program="$direnv_bin/direnv-reload"

  local bash_path
  bash_path="$(type -P bash)"

  local reload_file_escaped
  reload_file_escaped="$(printf '%q' "$reload_file")"

  # TODO(perf): To avoid always remaking this file, we could add the version of this
  # script to the file name and make a symlink to it without the version. This way,
  # we could do a `-e` check to avoid creating the file again. This isn't done
  # because this script currently isn't versioned.
  #
  # Alternatively, direnv could set a variable before a script gets sourced with
  # `source_url` that contains the file hash.
  cat >"$reload_program" <<EOF
#!$bash_path
touch $reload_file_escaped
EOF

  if [[ ! -x $reload_program ]]; then
    chmod +x "$reload_program"
  fi
}
