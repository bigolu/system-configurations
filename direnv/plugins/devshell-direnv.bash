# This plugin loads and caches a devshell created by numtide/devshell[1]. The
# cache is invalidated whenever a watched file is modified. If it fails to load
# a new devshell, it'll fall back to the last cached one.
#
# Differences from nix-direnv:
#   - This plugin only supports numtide/devshell[1].
#   - nix-direnv will only fall back to the old environment if the _build_ of
#     the new environment fails. This plugin will also fall back if the
#     _evaluation_ of the new environment fails.
#   - No GC root creation: Devshells already provide a way to set up the
#     environment through the `startup.*` options. Therefore, they should be
#     able to handle all of the environment management themselves so they can be
#     less dependent on direnv. To help with this, I wrote a nix utility that
#     handles GC roots.
#   - No manual reload: If you want to reload manually, you can use my
#     direnv-manual-reload plugin. In most of the `.envrc` files that I've seen,
#     the only thing done is loading a devshell so a dedicated command to reload
#     nix would be redundant.
#   - No automatic file watching: I don't think there's a way to do it that will
#     satisfy all use cases so users will still have to run `watch_file`
#     themselves. It's also a bit expensive to call since it shells out to
#     `direnv` so ideally you only call it once. And if users don't like the
#     files that were automatically watched, I'd have to also provide an option
#     to disable it. Instead, you can try the following which should work for
#     most cases:
#     ```
#     shopt -s globstar
#     watch_file nix/** **/*.nix **/flake.lock
#     shopt +s globstar
#     ```
#
# [1]: https://github.com/numtide/devshell

function use_devshell {
  local -ra devshell_build_args=("$@")

  local cache_directory
  _devshell_get_cache_directory cache_directory
  local -r last_cache_time="$cache_directory/last-cache-time"
  local -r cached_devshell_script="$cache_directory/env.bash"
  local -r cached_devshell_args="$cache_directory/args.txt"

  local IFS=' '
  local -r new_devshell_args_string="${devshell_build_args[*]@Q}"

  local should_refresh
  _devshell_should_refresh \
    should_refresh \
    "$last_cache_time" \
    "$cached_devshell_script" \
    "$cached_devshell_args" "$new_devshell_args_string"
  if [[ $should_refresh != 'true' ]]; then
    # shellcheck disable=1090
    source "$cached_devshell_script"
    return 0
  fi

  # This shell shouldn't exit if loading the new devshell fails. This way, we
  # can fall back.
  set +o errexit
  local export_statements
  export_statements="$(_devshell_load_new_devshell "${devshell_build_args[@]}")"
  local -r load_new_devshell_exit_code=$?
  set -o errexit

  if ((load_new_devshell_exit_code == 0)); then
    eval "$export_statements"
    _devshell_cache \
      "$cache_directory" \
      "$last_cache_time" \
      "$DEVSHELL_NEW_DEVSHELL_SCRIPT" "$cached_devshell_script" \
      "$new_devshell_args_string" "$cached_devshell_args"
    unset DEVSHELL_NEW_DEVSHELL_SCRIPT
  elif [[ -e $cached_devshell_script ]]; then
    _devshell_log_error 'Something went wrong, loading the last devshell'
    touch "$last_cache_time"
    # shellcheck disable=1090
    source "$cached_devshell_script"
  else
    return 1
  fi
}

# Why this is done in a subshell:
#   - To prevent any failures within it from causing the parent shell to exit.
#   - If any failures occur, we don't have to worry about unsetting any environment
#     variables that were set during the loading since they will only be set in the
#     subshell.
#
# It prints out its environment variables as `export` statements so they can be
# loaded into the parent shell.
function _devshell_load_new_devshell {
  (
    # Redirect stdout to stderr until we're ready to print the export statements
    local stdout_copy
    exec {stdout_copy}>&1
    exec 1>&2

    set -o errexit
    set -o nounset
    set -o pipefail

    local -ra devshell_build_args=("$@")

    DEVSHELL_NEW_DEVSHELL_SCRIPT="$(
      nix \
        --no-warn-dirty --extra-experimental-features 'nix-command flakes' \
        build --no-link --print-out-paths "${devshell_build_args[@]}"
    )/env.bash"
    export DEVSHELL_NEW_DEVSHELL_SCRIPT

    # shellcheck disable=1090
    source "$DEVSHELL_NEW_DEVSHELL_SCRIPT"

    # `declare -px` doesn't work[1] so we use POSIX exports instead.
    #
    # [1]: https://github.com/direnv/direnv/issues/222
    set -o posix
    exec 1>&"$stdout_copy"
    export -p
  )
}

function _devshell_cache {
  local -r \
    cache_directory="$1" \
    last_cache_time="$2" \
    new_devshell_script="$3" cached_devshell_script="$4" \
    new_devshell_args_string="$5" cached_devshell_args="$6"

  # We use `-f` to avoid a race condition between multiple instances of direnv e.g. a
  # direnv editor extension and the terminal.
  rm -f "$cache_directory/"*

  touch "$last_cache_time"

  # We use `-nf` to avoid a race condition between multiple instances of direnv e.g.
  # a direnv editor extension and the terminal.
  ln -nfs "$new_devshell_script" "$cached_devshell_script"

  # It must be atomic to avoid a race condition between multiple instances
  # of direnv e.g. a direnv editor extension and the terminal.
  _devshell_atomic_make_file "$new_devshell_args_string" "$cached_devshell_args"
}

function _devshell_atomic_make_file {
  local -r content="$1"
  local -r path="$2"

  local temp
  temp="$(mktemp)"

  echo "$content" >"$temp"
  # We use `-f` to avoid a race condition between multiple instances of direnv e.g. a
  # direnv editor extension and the terminal.
  mv -f "$temp" "$path"
}

function _devshell_get_cache_directory {
  local -n _cache_directory=$1

  _cache_directory="$(direnv_layout_dir)/devshell-direnv"
  if [[ ! -d $_cache_directory ]]; then
    # Besides creating parent directories, we also use `-p` to avoid a race condition
    # between multiple instances of direnv e.g. a direnv editor extension and the
    # terminal.
    mkdir -p "$_cache_directory"
  fi
}

function _devshell_should_refresh {
  local -n _should_refresh=$1
  local -r last_cache_time="$2"
  local -r cached_devshell_script="$3"
  local -r cached_devshell_args="$4"
  local -r new_devshell_args_string="$5"

  local is_cache_fresh
  _devshell_is_cache_fresh is_cache_fresh "$last_cache_time"

  if
    [[ -e $cached_devshell_script &&
      -e $cached_devshell_args &&
      $(<"$cached_devshell_args") == "$new_devshell_args_string" &&
      $is_cache_fresh == 'true' ]]
  then
    _should_refresh=false
  else
    _should_refresh=true
  fi
}

function _devshell_is_cache_fresh {
  local -n _is_cache_fresh=$1
  local -r last_cache_time="$2"

  _is_cache_fresh=true
  local -a watched_files
  shopt -s lastpipe
  # shellcheck disable=2312
  # pipefail will be enabled when direnv runs
  direnv watch-print --null | { readarray -d '' watched_files; }
  shopt -u lastpipe
  local file
  for file in "${watched_files[@]}"; do
    if
      [[ $file != "${XDG_DATA_HOME:-$HOME/.local/share}/direnv/"* &&
        $file -nt $last_cache_time ]]
    then
      _is_cache_fresh=false
      break
    fi
  done
}

function _devshell_log_error {
  local -r message="$1"

  local color_normal=
  local color_red_bold=
  if [[ -t 2 ]]; then
    printf -v color_normal '%b' '\e[m'
    printf -v color_red_bold '%b' '\e[1m\e[31m'
  fi

  log_error "${color_red_bold}[devshell-direnv] ERROR: ${message}${color_normal}"
}
