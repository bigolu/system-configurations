# Differences from nix-direnv:
#   - No GC root creation: The various nix dev shell implementations already provide
#     a way to set up the environment e.g. `shellHook` for nix's devShell or
#     `startup.*` for numtide's devshell. As such, I think that nix should handle all
#     of its environment loading so nix can be less coupled with direnv. To help with
#     this, I wrote a nix utility that handles GC roots so I wouldn't need direnv to
#     do that.
#   - Fast: This intentionally doesn't offer much configuration or features to make
#     it as fast as possible.
#
# Essentially this plugin just loads the environment and reloads it whenever a
# watched file is modified.

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
    # perf: The exit code of direnv is being masked by readarray, but it would be
    # tricky to avoid that. I can't use a pipeline since I want to unset the
    # DIRENV_WATCHES environment variable below. I could put the output of the direnv
    # command in a temporary file, but since this runs every time you enter the project
    # directory I want to avoid doing anything slow.
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
