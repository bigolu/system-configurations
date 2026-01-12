# This plugin loads and caches a nix environment. The cache is invalidated whenever a
# watched file is modified. If it fails to load a new environment, it'll fall back to
# the last cached one.
#
# Some differences from nix-direnv:
#   - nix-direnv will only fall back to the old environment if the _build_ of the new
#     environment fails. This plugin will also fall back if the _evaluation_ of the
#     new environment fails.
#   - (Almost) No GC root creation: Dev shell implementations already provide a way
#     to set up the environment e.g. `shellHook` for nix's devShell or `startup.*`
#     for numtide's devshell. Therefore, nix should be able to handle all of its
#     environment management itself so it can be less dependent on direnv. To help
#     with this, I wrote a nix utility that handles GC roots. The one exception to
#     this is `packages` since they don't belong to a dev shell.
#   - No manual reload: If you want to reload manually, you can use my
#     direnv-manual-reload plugin. In most of the `.envrc` files that I've seen, the
#     only thing done is loading a nix environment so a dedicated command to reload
#     nix would be redundant.
#   - No automatic file watching: I don't want to have to emulate nix's argument
#     parsing so I can determine which arguments are files. I also don't want to
#     define my own argument schema. Plus, I don't think there's a way to do it that
#     will satisfy all use cases so users will still have to run `watch_file`
#     themselves. It's also a bit expensive to call since it shells out to `direnv`
#     so ideally you only call it once. And if users don't like the files that were
#     automatically watched, I'd have to also provide an option to disable it.
#     Instead, you can try the following which should work for most cases:
#     ```
#     shopt -s globstar
#     watch_file nix/** **/*.nix **/flake.lock
#     shopt +s globstar
#     ```

function use_nix {
  # The type of environment. See the case statement below for valid values.
  local -r env_type="$1"
  # Arguments used for building the environment. See the case statement below for how
  # they will be used.
  local -ra env_build_args=("${@:2}")

  local cache_directory
  _mnd_get_cache_directory cache_directory
  # Keep a symlink to the environment so we can ensure it still exists
  local -r cached_env="$cache_directory/env"
  local -r cached_env_script="$cache_directory/env.bash"
  local -r cached_env_args="$cache_directory/env-args.txt"

  local IFS=' '
  local -r new_env_args_string="$env_type ${env_build_args[*]@Q}"

  local should_reload
  _mnd_should_reload \
    should_reload \
    "$cached_env" "$cached_env_script" "$cached_env_args" "$new_env_args_string"
  if [[ $should_reload != 'true' ]]; then
    # shellcheck disable=1090
    source "$cached_env_script"
    return 0
  fi

  # This shell shouldn't exit if loading fails so we can fall back
  set +o errexit
  local export_statements
  export_statements="$(
    _mnd_load_new_env "$cache_directory" "$env_type" "${env_build_args[@]}"
  )"
  local -r load_new_env_exit_code=$?
  set -o errexit

  if ((load_new_env_exit_code == 0)); then
    eval "$export_statements"
    _mnd_cache \
      "$cache_directory" "$env_type" \
      "$MND_NEW_ENV_SCRIPT_CONTENTS" "$cached_env_script" \
      "$MND_NEW_ENV" "$cached_env" \
      "$new_env_args_string" "$cached_env_args"
    unset MND_NEW_ENV MND_NEW_ENV_SCRIPT_CONTENTS
  elif [[ -e $cached_env_script ]]; then
    _mnd_log_error 'Something went wrong, loading the last environment'
    # Consider the cached environment script up to date.
    touch "$cached_env_script"
    # shellcheck disable=1090
    source "$cached_env_script"
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
function _mnd_load_new_env {
  (
    # Redirect stdout to stderr until we're ready to print the export statements
    local stdout_copy
    exec {stdout_copy}>&1
    exec 1>&2

    set -o errexit
    set -o nounset
    set -o pipefail

    local -r cache_directory="$1"
    local -r env_type="$2"
    local -ra env_build_args=("${@:3}")

    export MND_NEW_ENV MND_NEW_ENV_SCRIPT_CONTENTS
    _mnd_build_new_env \
      MND_NEW_ENV MND_NEW_ENV_SCRIPT_CONTENTS \
      "$cache_directory" "$env_type" "${env_build_args[@]}"

    eval "$MND_NEW_ENV_SCRIPT_CONTENTS"

    # `declare -px` doesn't work[1] so we use POSIX exports instead.
    #
    # [1]: https://github.com/direnv/direnv/issues/222
    set -o posix
    exec 1>&"$stdout_copy"
    export -p
  )
}

function _mnd_cache {
  local -r \
    cache_directory="$1" env_type="$2" \
    new_env_script_contents="$3" cached_env_script="$4" \
    new_env="$5" cached_env="$6" \
    new_env_args_string="$7" cached_env_args="$8"

  # We use `-f` to avoid a race condition between multiple instances of direnv e.g. a
  # direnv editor extension and the terminal.
  rm -f "$cache_directory/"*

  # It must be atomic to avoid a race condition between multiple instances
  # of direnv e.g. a direnv editor extension and the terminal.
  atomic_make_file "$new_env_script_contents" "$cached_env_script"

  # We use `-nf` to avoid a race condition between multiple instances of direnv e.g.
  # a direnv editor extension and the terminal.
  ln -nfs "$new_env" "$cached_env"

  # It must be atomic to avoid a race condition between multiple instances
  # of direnv e.g. a direnv editor extension and the terminal.
  atomic_make_file "$new_env_args_string" "$cached_env_args"

  if [[ $env_type == 'packages' ]]; then
    _mnd_nix build --out-link "$cache_directory/env-gc-root" "$new_env"
  fi
}

function atomic_make_file {
  local -r content="$1"
  local -r path="$2"

  local temp
  temp="$(mktemp)"

  echo "$content" >"$temp"
  mv "$temp" "$path"
}

function _mnd_get_cache_directory {
  local -n _cache_directory=$1

  _cache_directory="$(direnv_layout_dir)/minimal-nix-direnv"
  if [[ ! -d $_cache_directory ]]; then
    # Besides creating parent directories, we also use `-p` to avoid a race condition
    # between multiple instances of direnv e.g. a direnv editor extension and the
    # terminal.
    mkdir -p "$_cache_directory"
  fi
}

function _mnd_should_reload {
  local -n _should_reload=$1
  local -r cached_env="$2"
  local -r cached_env_script="$3"
  local -r cached_env_args="$4"
  local -r new_env_args_string="$5"

  local is_cache_fresh
  _mnd_is_cache_fresh is_cache_fresh "$cached_env_script"

  if
    [[ -e $cached_env &&
      -e $cached_env_script &&
      -e $cached_env_args &&
      $(<"$cached_env_args") == "$new_env_args_string" &&
      $is_cache_fresh == 'true' ]]
  then
    _should_reload=false
  else
    _should_reload=true
  fi
}

function _mnd_is_cache_fresh {
  local -n _is_cache_fresh=$1
  local -r cached_env_script="$2"

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
        $file -nt $cached_env_script ]]
    then
      _is_cache_fresh=false
      break
    fi
  done
}

function _mnd_build_new_env {
  local -n _new_env=$1
  local -n _new_env_script_contents=$2
  local -r cache_directory="$3"
  local -r env_type="$4"
  local -a env_build_args=("${@:5}")

  case "$env_type" in
    # `packages` is almost the same as `dev_shell`. The only difference is that when
    # `packages` is used, we define the dev shell on behalf of the user, containing
    # the packages they specify.
    'packages')
      local IFS=' '
      env_build_args=(
        --impure
        --expr "
          with import <nixpkgs> {};
          mkShell { buildInputs = [ ${env_build_args[*]} ]; }
        "
      )
      ;&
    'dev_shell')
      # Add the PID to the profile name to avoid a race condition between multiple
      # instances of direnv e.g. a direnv editor extension and the terminal. Without
      # this, one direnv instance can delete the tmp profile before the other
      # instance is able to run `realpath` further down so instead we give each
      # instance its own profile.
      local -r tmp_profile="$cache_directory/tmp-profile-$$"

      # shellcheck disable=2016
      #
      # We have to restore certain variables that nix and lix shouldn't be
      # overwriting. When they stop overwriting these variables[1][2], we can remove
      # this.
      #
      # [1]: https://github.com/NixOS/nixpkgs/pull/330822/files
      # [2]: https://git.lix.systems/lix-project/lix/issues/979
      _new_env_script_contents='
        declare -A _mnd_values_to_restore=(
          ["NIX_BUILD_TOP"]=${NIX_BUILD_TOP:-__UNSET__}
          ["NIX_ATTRS_JSON_FILE"]=${NIX_ATTRS_JSON_FILE:-__UNSET__}
          ["NIX_ATTRS_SH_FILE"]=${NIX_ATTRS_SH_FILE:-__UNSET__}
          ["TMP"]=${TMP:-__UNSET__}
          ["TMPDIR"]=${TMPDIR:-__UNSET__}
          ["TEMP"]=${TEMP:-__UNSET__}
          ["TEMPDIR"]=${TEMPDIR:-__UNSET__}
          ["terminfo"]=${terminfo:-__UNSET__}
        )
      '"$(_mnd_nix print-dev-env --profile "$tmp_profile" "${env_build_args[@]}")"'
        for _mnd_key in "${!_mnd_values_to_restore[@]}"; do
          _mnd_value=${_mnd_values_to_restore[$_mnd_key]}
          if [[ $_mnd_value == __UNSET__ ]]; then
            unset "$_mnd_key"
          else
            export "$_mnd_key=$_mnd_value"
          fi
        done
      '

      _new_env="$(realpath "$tmp_profile")"

      rm "$tmp_profile"*
      ;;
    *)
      _mnd_log_error "Unknown environment type: $env_type"
      return 1
      ;;
  esac
}

function _mnd_nix {
  nix --no-warn-dirty --extra-experimental-features 'nix-command flakes' "$@"
}

function _mnd_log_error {
  local -r message="$1"

  local color_normal=
  local color_red_bold=
  if [[ -t 2 ]]; then
    printf -v color_normal '%b' '\e[m'
    printf -v color_red_bold '%b' '\e[1m\e[31m'
  fi

  log_error "${color_red_bold}[minimal-nix-direnv] ERROR: ${message}${color_normal}"
}
