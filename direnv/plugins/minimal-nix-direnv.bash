# This plugin caches and loads a nix environment. The cache is invalidated whenever a
# watched file is modified. If it fails to load a new environment, it'll fall back to
# the last cached one.
#
# Some differences from nix-direnv:
#   - nix-direnv will only fall back to the old environment if the _build_ of the new
#     environment fails. This plugin will also fall back if the _evaluation_ of the
#     new environment fails.
#   - No GC root creation: Dev shell implementations already provide a way to set up
#     the environment e.g. `shellHook` for nix's devShell or `startup.*` for
#     numtide's devshell. Therefore, nix should be able to handle all of its
#     environment management itself so it can be less dependent on direnv. To help
#     with this, I wrote a nix utility that handles GC roots.
#   - No manual reload: If you want to reload manually, you can use my
#     direnv-manual-reload plugin. In most of the `.envrc` files that I've seen, the
#     only thing done is loading a nix environment so a dedicated command to reload
#     nix would be redundant.
#   - No automatic file watching: I don't want to have to emulate nix's argument
#     parsing so I can determine which arguments are files. I also don't want to
#     define my own argument schema. Plus, I don't think there's a way to do it that
#     will satisfy all use cases so users will still have to run `watch_file`
#     themselves. Instead, you can try the following which should work for most
#     cases: watch_file nix/** **/*.nix

function use_nix {
  # The name of the dev shell implementation. See the case statement below for valid
  # values.
  local -r type="$1"
  # These will be appended to `nix build` to get the devshell package.
  local -ra args=("${@:2}")

  # Intentionally global so it can be accessed from the fallback trap
  _mnd_cached_env_script="$(direnv_layout_dir)/dev-shell-env.bash"

  local should_update=false
  if [[ ! -e $_mnd_cached_env_script ]]; then
    should_update=true
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
      if [[ $file -nt $_mnd_cached_env_script ]]; then
        should_update=true
        break
      fi
    done
  fi

  if [[ $should_update != 'true' ]]; then
    # shellcheck disable=1090
    source "$_mnd_cached_env_script"
    return 0
  fi

  # If the command for getting the new env script, or the script itself, fails, we'll
  # restore the environment from before they ran and source the last cached env
  # script.
  #
  # Intentionally global so it can be accessed from the fallback trap
  _mnd_original_env="$(declare -px)"
  # direnv already sets an exit trap so we'll prepend our command to it instead of
  # overwriting it.
  local original_trap
  original_trap="$(_mnd_get_exit_trap)"
  # TODO: I tried to use a function for the trap, but I got an error: If there was a
  # function inside the cached env script that used local variables, Bash would exit
  # with the error "local cannot be used outside of a function", even though it was
  # in a function. If I wrapped that function inside another function, then it would
  # work. This is why the `eval` statement in the trap below is inside a function.
  # Without it, I got an error.
  trap -- '
    if [[ -e "$_mnd_cached_env_script" ]]; then
      _mnd_log_error "Something went wrong, loading the last dev shell"

      # A faster, built-in alternative to `touch`. Though, if the file did not
      # initially end with a newline, this would add one, but that is not a problem
      # here.
      echo "$(<"$_mnd_cached_env_script")" >"$_mnd_cached_env_script"

      # Clear env
      readarray -t vars <<<"$(set -o posix; export -p; set +o posix)"
      for var in "${vars[@]}"; do
        # Remove everything from the first `=` onwards
        var="${var%%=*}"
        # The substring removes `export `
        unset "${var:7}"
      done

      function _mnd_nest_1 {
        function _mnd_nest_2 {
          eval "$_mnd_original_env"
        }
        _mnd_nest_2
      }
      _mnd_nest_1

      source "$_mnd_cached_env_script"
    fi
  '"$original_trap" EXIT

  local new_env_script
  # Nix may add a standard format for dev shell packages[1]. If this is done, then
  # the environment script will always be in `<package>/lib/env.bash`.
  #
  # [1]: https://github.com/NixOS/nixpkgs/pull/330822/files
  case "$type" in
    # numtide/devshell
    'devshell')
      new_env_script="$(_mnd_nix build --no-link --print-out-paths "${args[@]}")/env.bash"
      ;;
    *)
      _mnd_log_error "Unknown dev shell type: $type"
      return 1
      ;;
  esac

  # shellcheck disable=1090
  source "$new_env_script"

  trap -- "$original_trap" EXIT

  local -r cached_env_script_directory="${_mnd_cached_env_script%/*}"
  if [[ ! -d $cached_env_script_directory ]]; then
    mkdir -p "$cached_env_script_directory"
  fi
  echo "$(<"$new_env_script")" >"$_mnd_cached_env_script"
}

function _mnd_nix {
  nix --no-warn-dirty --extra-experimental-features "nix-command flakes" "$@"
}

function _mnd_log_error {
  local -r message="$1"

  local color_normal=
  local color_error=
  if [[ -t 2 ]]; then
    color_normal='\e[m'
    color_error='\e[1m\e[31m'
  fi

  printf '%b' "$color_error"
  log_error "[minimal-nix-direnv] ERROR: $message"
  printf '%b' "$color_normal"
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
