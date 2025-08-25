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
  local -r _mnd_env_type="$1"
  # Arguments used for building the environment. See the case statement below for how
  # they will be used.
  local -ra env_build_args=("${@:2}")

  local _mnd_cache_directory
  _mnd_get_cache_directory _mnd_cache_directory
  # Keep a symlink to the environment so we can ensure it still exists
  local -r _mnd_cached_env="$_mnd_cache_directory/env"
  local -r _mnd_cached_env_script="$_mnd_cache_directory/env.bash"
  local -r _mnd_cached_env_args="$_mnd_cache_directory/env-args.txt"

  local IFS=' '
  local -r _mnd_new_env_args="$_mnd_env_type ${env_build_args[*]}"

  local should_update
  _mnd_should_update \
    should_update \
    "$_mnd_cached_env" "$_mnd_cached_env_script" "$_mnd_cached_env_args" "$_mnd_new_env_args"
  if [[ $should_update != 'true' ]]; then
    # shellcheck disable=1090
    source "$_mnd_cached_env_script"
    return 0
  fi

  local _mnd_original_trap
  _mnd_set_fallback_trap _mnd_original_trap "$_mnd_cached_env_script"

  local _mnd_new_env
  local _mnd_new_env_script_contents
  _mnd_build_new_env \
    _mnd_new_env _mnd_new_env_script_contents \
    "$_mnd_cache_directory" "$_mnd_env_type" "${env_build_args[@]}"

  eval "$_mnd_new_env_script_contents"

  # WARNING
  # ---------------------------------------------------------------------------------
  # Any variables accessed after this comment should have the prefix `_mnd_` to
  # reduce the chance of being overwritten by the environment script that was
  # evaluated before this comment.

  trap -- "$_mnd_original_trap" EXIT
  _mnd_cache \
    "$_mnd_cache_directory" "$_mnd_env_type" \
    "$_mnd_new_env_script_contents" "$_mnd_cached_env_script" \
    "$_mnd_new_env" "$_mnd_cached_env" \
    "$_mnd_new_env_args" "$_mnd_cached_env_args"
}

function _mnd_cache {
  local -r \
    cache_directory="$1" env_type="$2" \
    new_env_script_contents="$3" cached_env_script="$4" \
    new_env="$5" cached_env="$6" \
    new_env_args="$7" cached_env_args="$8"

  # Why we use `-f`:
  #   - Avoid a race condition between multiple instances of direnv e.g. a direnv
  #     editor extension and the terminal.
  #   - Avoid an error if the directory is empty
  rm -f "$cache_directory/"*
  echo "$new_env_script_contents" >"$cached_env_script"
  # We use `-nf` to avoid a race condition between multiple instances of direnv e.g.
  # a direnv editor extension and the terminal.
  ln -nfs "$new_env" "$cached_env"
  echo "$new_env_args" >"$cached_env_args"
  if [[ $env_type == 'packages' ]]; then
    _mnd_nix build --out-link "$cache_directory/env-gc-root" "$new_env"
  fi
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

function _mnd_set_fallback_trap {
  local -n _original_trap=$1
  local -r cached_env_script="$2"

  # Intentionally global so they can be accessed from the fallback trap
  _mnd_global_cached_env_script="$cached_env_script"
  _mnd_global_original_env="$(declare -px)"

  # direnv already sets an exit trap so we'll prepend our command to it instead of
  # overwriting it.
  _original_trap="$(_mnd_get_exit_trap)"
  # TODO: I tried to use a function for the trap, but I got an error: If there was a
  # function inside the cached env script that used local variables, Bash would exit
  # with the error "local cannot be used outside of a function", even though it was
  # in a function. If I wrapped that function inside another function, then it would
  # work. This is why the `eval` statement in the trap below is inside a function.
  # Without it, I got a similar error.
  trap -- '
    if [[ -e "$_mnd_global_cached_env_script" ]]; then
      _mnd_log_error "Something went wrong, loading the last environment"

      # Consider the cached environment script up to date.
      #
      # A built-in alternative to `touch`. Though, if the file did not initially end
      # with a newline, this would add one, but that is not a problem here.
      echo "$(<"$_mnd_global_cached_env_script")" >"$_mnd_global_cached_env_script"

      # Clear env
      readarray -t vars <<<"$(set -o posix; export -p)"
      for var in "${vars[@]}"; do
        # Remove everything from the first `=` onwards
        var="${var%%=*}"
        # The substring removes `export `
        unset "${var:7}"
      done

      function _mnd_nest_1 {
        function _mnd_nest_2 {
          eval "$_mnd_global_original_env"
        }
        _mnd_nest_2
      }
      _mnd_nest_1

      source "$_mnd_global_cached_env_script"
    fi
  '"$_original_trap" EXIT
}

function _mnd_should_update {
  local -n _should_update=$1
  local -r cached_env="$2"
  local -r cached_env_script="$3"
  local -r cached_env_args="$4"
  local -r new_env_args="$5"

  _should_update=false
  if [[ ! -e $cached_env || ! -e $cached_env_script || $(<"$cached_env_args") != "$new_env_args" ]]; then
    _should_update=true
  else
    local -a watched_files
    # shellcheck disable=2312
    # PERF: The exit code of direnv is being masked by readarray, but the alternative
    # ways to do this are slower: I could use a pipeline, but that would spawn a
    # subprocess. I could put the output of the direnv command in a temporary file,
    # but I want to avoid the disk.
    readarray -d '' watched_files < <(direnv watch-print --null)
    local file
    for file in "${watched_files[@]}"; do
      if [[ $file -nt $cached_env_script ]]; then
        _should_update=true
        break
      fi
    done
  fi
}

function _mnd_build_new_env {
  local -n _new_env=$1
  local -n _new_env_script_contents=$2
  local -r cache_directory="$3"
  local -r env_type="$4"
  local -a env_build_args=("${@:5}")

  case "$env_type" in
    # numtide/devshell
    'devshell')
      _new_env="$(_mnd_nix build --no-link --print-out-paths "${env_build_args[@]}")"
      _new_env_script_contents="$(<"$_new_env/env.bash")"
      ;;
    'packages') ;&
    # Nix is changing the format for dev shells[1] so this will need to be updated
    # when that happens.
    #
    # [1]: https://github.com/NixOS/nixpkgs/pull/330822/files
    'stdenv')
      # Add the PID to the profile name to avoid a race condition between multiple
      # instances of direnv e.g. a direnv editor extension and the terminal. Without
      # this, one direnv instance can delete the tmp profile before the other
      # instance is able to run `realpath` further down so instead we give each
      # instance its own profile.
      local -r tmp_profile="$cache_directory/tmp-profile-$$"

      if [[ $env_type == 'packages' ]]; then
        local IFS=' '
        env_build_args=(
          --impure
          --expr "with import <nixpkgs> {}; mkShell { buildInputs = [ ${env_build_args[*]} ]; }"
        )
      fi

      # We store the script in a string instead of a file to avoid a race condition
      # between multiple instances of direnv e.g. a direnv editor extension and the
      # terminal.
      #
      # shellcheck disable=2016
      _new_env_script_contents='
        declare -A _mnd_values_to_restore=(
          ["NIX_BUILD_TOP"]=${NIX_BUILD_TOP:-__UNSET__}
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
  local color_error=
  if [[ -t 2 ]]; then
    color_normal=$(printf '%b' '\e[m')
    color_error=$(printf '%b' '\e[1m\e[31m')
  fi

  log_error "${color_error}[minimal-nix-direnv] ERROR: ${message}${color_normal}"
}

function _mnd_get_exit_trap {
  # `trap -p EXIT` will print 'trap -- <current_trap> EXIT'. The output seems to be
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
