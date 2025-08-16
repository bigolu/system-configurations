# This plugin caches and loads a nix environment. The cache is invalidated whenever a
# watched file is modified. If it fails to load a new environment, it'll fall back to
# the last cached one.
#
# Differences from nix-direnv:
#   - Much less features. Some notable ones are:
#     - No GC root creation: Nix dev shell implementations already provide a way to
#       set up the environment e.g. `shellHook` for nix's devShell or `startup.*` for
#       numtide's devshell. Therefore, nix should be able to handle all of its
#       environment management itself so it can be less dependent on direnv. To help
#       with this, I wrote a nix utility that handles GC roots.
#     - No manual reload: If you want to reload manually, you can use my
#       direnv-manual-reload plugin. In most of the `.envrc` files that I've seen,
#       the only thing done is loading a nix environment so a dedicated command to
#       reload nix would be redundant.
#   - It also felt like there was less of a pause when entering a directory so it may
#     be a bit faster. I did a rough benchmark with `hyperfine` and this plugin was
#     faster by about half a second.

function use_nix {
  # The name of the dev shell implementation. See the case statement below for valid
  # values.
  local -r type="$1"
  # These will be appended to `nix build` to get the devshell package.
  local -ra args=("${@:2}")

  # Intentionally global so it can be accessed from a trap
  _mnd_cached_env_script="${direnv_layout_dir:-.direnv}/dev-shell-env.bash"

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

  # direnv already sets an exit trap so we'll prepend our command to it instead
  # of overwriting it.
  local original_trap
  original_trap="$(_mnd_get_exit_trap)"
  # I tried to use a function for the trap, but I got a strange error: If there was a
  # function inside the dev shell shellHook that used local variables, Bash would
  # exit with the error "local cannot be used outside of a function" even though it
  # was in a function.
  trap -- '
    touch "$_mnd_cached_env_script"
    _mnd_log_error "Something went wrong, loading the last dev shell"
    source "$_mnd_cached_env_script"
  '"$original_trap" EXIT

  local new_env_script
  # Nix may add a standard format for dev shell packages[1]. If this is done, then
  # the environment script will always be in `<package>/lib/env.bash`.
  #
  # [1]: https://github.com/NixOS/nixpkgs/pull/330822/files
  case "$type" in
    # numtide/devshell
    'devshell')
      new_env_script="$(nix build --no-link --print-out-paths "${args[@]}")/env.bash"
      ;;
    *)
      _mnd_log_error "Unknown dev shell type: $type"
      return 1
      ;;
  esac

  # shellcheck disable=1090
  source "$new_env_script"
  local -r cached_env_script_directory="${_mnd_cached_env_script%/*}"
  if [[ ! -d $cached_env_script_directory ]]; then
    mkdir -p "$cached_env_script_directory"
  fi
  echo "$(<"$new_env_script")" >"$_mnd_cached_env_script"

  trap -- "$original_trap" EXIT
}

function _mnd_log_error {
  log_error "minimal-nix-direnv: error: $1"
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
