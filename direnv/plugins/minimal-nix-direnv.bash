# This plugin caches and loads a nix environment. The cache is invalidated whenever a
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
#     `watch_file nix/** **/*.nix`

function use_nix {
  # The name of the dev shell implementation. See the case statement below for valid
  # values.
  local -r type="$1"
  # See the case statement below for how this will be used.
  local -ra args=("${@:2}")

  local prefix
  _mnd_get_prefix prefix
  local -r link_to_cached_shell="$prefix/link-to-cached-shell"
  local -r cached_env_script="$prefix/env.bash"

  local should_update
  _mnd_should_update should_update "$link_to_cached_shell" "$cached_env_script"
  if [[ $should_update != 'true' ]]; then
    # shellcheck disable=1090
    source "$cached_env_script"
    return 0
  fi

  local original_trap
  _mnd_set_fallback_trap original_trap "$cached_env_script"

  local new_shell
  local new_env_script
  _mnd_build_new_shell new_shell new_env_script "$prefix" "$type" "${args[@]}"

  # shellcheck disable=1090
  source "$new_env_script"

  trap -- "$original_trap" EXIT

  echo "$(<"$new_env_script")" >"$cached_env_script"
  rm -f "$link_to_cached_shell"
  ln -fs "$new_shell" "$link_to_cached_shell"
}

function _mnd_get_prefix {
  local -n _prefix=$1

  _prefix="$(direnv_layout_dir)/minimal-nix-direnv"
  if [[ ! -d $_prefix ]]; then
    mkdir -p "$_prefix"
  fi
}

function _mnd_set_fallback_trap {
  local -n _original_trap=$1
  local -r cached_env_script="$2"

  # Intentionally global so it can be accessed from the fallback trap
  _mnd_cached_env_script="$cached_env_script"

  # If the command for getting the new env script, or the script itself, fails, we'll
  # restore the environment from before they ran and source the last cached env
  # script.
  #
  # Intentionally global so it can be accessed from the fallback trap
  _mnd_original_env="$(declare -px)"

  # direnv already sets an exit trap so we'll prepend our command to it instead of
  # overwriting it.
  _original_trap="$(_mnd_get_exit_trap)"
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
  '"$_original_trap" EXIT
}

function _mnd_should_update {
  local -n _should_update=$1
  local -r link_to_cached_shell="$2"
  local -r cached_env_script="$3"

  _should_update=false
  if [[ ! -e $link_to_cached_shell || ! -e $cached_env_script ]]; then
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

function _mnd_build_new_shell {
  local -n _new_shell=$1
  local -n _new_env_script=$2
  local -r prefix="$3"
  local -r type="$4"
  local -ra args=("${@:5}")

  # Nix may add a standard format for dev shell packages[1]. If this is done, then
  # the environment script will always be in `<package>/lib/env.bash`.
  #
  # [1]: https://github.com/NixOS/nixpkgs/pull/330822/files
  case "$type" in
    # numtide/devshell
    'devshell')
      _new_shell="$(_mnd_nix build --no-link --print-out-paths "${args[@]}")"
      _new_env_script="$_new_shell/env.bash"
      ;;
    'mk_shell') ;&
    'packages')
      local -r tmp_profile="$prefix/tmp-profile"
      local -r tmp_env_script="$prefix/tmp-env.bash"
      # shellcheck disable=2016
      echo '
        function _mnd_restore_vars {
          local -A values_to_restore=(
            ["NIX_BUILD_TOP"]=${NIX_BUILD_TOP:-__UNSET__}
            ["TMP"]=${TMP:-__UNSET__}
            ["TMPDIR"]=${TMPDIR:-__UNSET__}
            ["TEMP"]=${TEMP:-__UNSET__}
            ["TEMPDIR"]=${TEMPDIR:-__UNSET__}
            ["terminfo"]=${terminfo:-__UNSET__}
          )
      ' >"$tmp_env_script"
      local -a nix_args
      if [[ $type == 'packages' ]]; then
        IFS=' ' nix_args=(
          --impure
          --expr "with import <nixpkgs> {}; mkShell { buildInputs = [ ${args[*]} ]; }"
        )
      else
        nix_args=("${args[@]}")
      fi
      _mnd_nix print-dev-env --profile "$tmp_profile" "${nix_args[@]}" >>"$tmp_env_script"
      _mnd_nix profile wipe-history --profile "$tmp_profile"
      # shellcheck disable=2016
      echo '
          local key
          for key in "${!values_to_restore[@]}"; do
            local value=${values_to_restore[$key]}
            if [[ $value == __UNSET__ ]]; then
              unset "$key"
            else
              export "$key=$value"
            fi
          done
        }
        _mnd_restore_vars
      ' >>"$tmp_env_script"

      _new_shell="$tmp_profile"
      _new_env_script="$tmp_env_script"
      ;;
    *)
      _mnd_log_error "Unknown dev shell type: $type"
      return 1
      ;;
  esac
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
