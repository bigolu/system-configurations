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
  cached_env_script="${direnv_layout_dir:-.direnv}/dev-shell-env.bash"

  local should_update=false
  if [[ ! -e $cached_env_script ]]; then
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
      if [[ $file -nt $cached_env_script ]]; then
        should_update=true
        break
      fi
    done
  fi

  if [[ $should_update != 'true' ]]; then
    # shellcheck disable=1090
    source "$cached_env_script"
  else
    local original_trap
    original_trap="$(_mnd_get_exit_trap)"
    # direnv already sets an exit trap so we'll prepend our command to it instead
    # of overwriting it.
    _mnd_prepend_to_exit_trap "$(
      printf \
        'touch %q; _mnd_log_error %q; source %q' \
        "$cached_env_script" \
        "Something went wrong, loading the last dev shell" \
        "$cached_env_script"
    )"

    local new_env_script
    # Nix may add a standard format for dev shell packages[1]. If this is done, then
    # this plugin won't need separate handlers for each dev shell implementation
    # since the script for loading the environment will always be in
    # `<package>/lib/env.bash`.
    #
    # [1]: https://github.com/NixOS/nixpkgs/pull/330822/files
    case "$type" in
      # numtide/devshell
      'devshell')
        local package
        package="$(nix build --no-link --print-out-paths "${args[@]}")"
        new_env_script="$package/env.bash"
        ;;
      *)
        _mnd_log_error "Unknown dev shell type: $type"
        return 1
        ;;
    esac

    # shellcheck disable=1090
    source "$new_env_script"

    local -r cached_env_script_directory="${cached_env_script%/*}"
    if [[ ! -d $cached_env_script_directory ]]; then
      mkdir -p "$cached_env_script_directory"
    fi
    echo "$(<"$new_env_script")" >"$cached_env_script"

    trap -- "$original_trap" EXIT
  fi
}

function _mnd_log_error {
  log_error "minimal-nix-direnv: $1"
}

function _mnd_prepend_to_exit_trap {
  local -r command="$1"

  local current_trap
  current_trap="$(_mnd_get_exit_trap)"

  trap -- "$command"$'\n'"$current_trap" EXIT
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
