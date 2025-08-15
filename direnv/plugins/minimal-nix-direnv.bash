# This plugin caches and loads a nix environment. The cache is invalidated whenever a
# watched file is modified.
#
# Differences from nix-direnv:
#   - No GC root creation: The various nix dev shell implementations already provide
#     a way to set up the environment e.g. `shellHook` for nix's devShell or
#     `startup.*` for numtide's devshell. Therefore, nix should be able to handle all
#     of its environment management itself so it can be less dependent on direnv. To
#     help with this, I wrote a nix utility that handles GC roots.
#   - No manual reload: If you want to reload manually, you can use my
#     direnv-manual-reload plugin. In most of the `.envrc` files that I've seen, the
#     only thing done is loading a nix environment so providing a dedicated command
#     to reload nix would be redundant.

function use_nix {
  # The name of the dev shell implementation. See the case statement below for valid
  # values.
  local -r type="$1"
  # These will be appended to `nix build` to get the devshell package.
  local -ra args=("${@:2}")

  local -r cached_env_script="${direnv_layout_dir:-.direnv}/dev-shell-env.bash"

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

  if [[ $should_update == 'true' ]]; then
    local new_env_script
    if new_env_script="$(_mnd_get_new_env_script "$type" "${args[@]}")"; then
      local -r cached_env_script_directory="${cached_env_script%/*}"
      if [[ ! -d $cached_env_script_directory ]]; then
        mkdir -p "$cached_env_script_directory"
      fi
      echo "$(<"$new_env_script")" >"$cached_env_script"
    else
      if [[ -e $cached_env_script ]]; then
        log_error 'Something went wrong, loading the last dev shell'
      else
        return 1
      fi
    fi
  fi

  # shellcheck disable=1090
  source "$cached_env_script"
}

function _mnd_get_new_env_script {
  local -r type="$1"
  local -ra args=("${@:2}")

  # Nix may add a standard format for dev shell packages[1]. If this is done, then
  # this plugin won't need separate handlers for each dev shell implementation since
  # the script for loading the environment will always be in
  # `<package>/lib/env.bash`.
  #
  # [1]: https://github.com/NixOS/nixpkgs/pull/330822/files
  case "$type" in
    # numtide/devshell
    'devshell')
      local package
      package="$(nix build --no-link --print-out-paths "${args[@]}")"
      echo "$package/env.bash"
      ;;
    *)
      log_error "Unknown dev shell type: $type"
      return 1
      ;;
  esac
}
