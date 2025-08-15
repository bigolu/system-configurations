# This plugin caches and loads a nix environment. The cache is invalidated whenever a
# watched file is modified.
#
# Differences from nix-direnv:
#   - Much less features. Some notable ones are:
#     - No GC root creation: The various nix dev shell implementations already
#       provide a way to set up the environment e.g. `shellHook` for nix's devShell
#       or `startup.*` for numtide's devshell. Therefore, nix should be able to
#       handle all of its environment management itself so it can be less dependent
#       on direnv. To help with this, I wrote a nix utility that handles GC roots.
#     - No manual reload: If you want to reload manually, you can use my
#       direnv-manual-reload plugin. In most of the `.envrc` files that I've seen,
#       the only thing done is loading a nix environment so providing a dedicated
#       command to reload nix would be redundant.
#   - A little faster. It felt like there was less of a pause when entering a
#     directory so I made a rough benchmark to confirm:
#       Command:
#         `hyperfine -m 50 --shell=none 'direnv exec . true'`
#       .envrc contents:
#         source <path_to_plugin>
#         use nix `devshell --file . devShell.development`/`-A devShells.development`
#       Results:
#         minimal-nix-direnv - 192 ms
#         nix-direnv - 596 ms
#
#       I also ran the same command with an empty .envrc and got 98 ms. This means
#       nix-direnv added 498 ms of overhead and minimal-nix-direnv added 94 ms which
#       makes minimal-nix-direnv 5.2x faster.

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
    local new_env_script=''

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
        if package="$(nix build --no-link --print-out-paths "${args[@]}")"; then
          new_env_script="$package/env.bash"
        fi
        ;;
      *)
        log_error "Unknown dev shell type: $type"
        ;;
    esac

    if [[ -n $new_env_script ]]; then
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
