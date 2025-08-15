# This plugin loads a nix environment, caches it, and invalidates the cache whenever
# a watched file is modified. If you want to invalidate manually, you can use my
# direnv-manual-reload plugin.
#
# Differences from nix-direnv:
#   - No GC root creation: The various nix dev shell implementations already provide
#     a way to set up the environment e.g. `shellHook` for nix's devShell or
#     `startup.*` for numtide's devshell. Therefore, nix should be able to handle all
#     of its environment management so it can be less dependent on direnv. To help
#     with this, I wrote a nix utility that handles GC roots.
#   - Fast: This intentionally doesn't offer much configuration or features to make
#     it as fast as possible.

# This is numtide's devshell, not nix's devShell
function use_devshell {
  # This will be appended to `nix build --print-out-paths` to get the devshell
  # package.
  local -ra args=("$@")

  local -r env_script="${direnv_layout_dir:-.direnv}/devshell-env.bash"

  local should_update=false
  if [[ ! -e $env_script ]]; then
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
      if [[ $file -nt $env_script ]]; then
        should_update=true
        break
      fi
    done
  fi

  if [[ $should_update == 'true' ]]; then
    local new_env_script
    if new_env_script="$(nix build --no-link --print-out-paths "${args[@]}")/env.bash"; then
      local -r env_script_directory="${env_script%/*}"
      if [[ ! -d $env_script_directory ]]; then
        mkdir -p "$env_script_directory"
      fi
      echo "$(<"$new_env_script")" >"$env_script"
    else
      if [[ -e $env_script ]]; then
        log_error 'Something went wrong, loading last devshell'
      else
        return
      fi
    fi
  fi

  # shellcheck disable=1090
  source "$env_script"
}
