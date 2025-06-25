set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# Inputs, via unexported variables:
# ACTIVATION_PACKAGE
# BASH_PATH
# INIT_SNIPPET (optional)
# USER_SHELL

echo 'Bootstrapping portable home...'

prefix_directory="$(mktemp --tmpdir --directory 'home_shell_XXXXX')"

# So we know where to find the prefix
export PORTABLE_HOME_PREFIX="$prefix_directory"

function clean_up {
  rm -rf "$prefix_directory"
}
trap clean_up EXIT

function make_directory_in_prefix {
  local new_directory_basename="$1"

  local new_directory="$prefix_directory/$new_directory_basename"
  mkdir "$new_directory"
  echo "$new_directory"
}

xdg_state_directory="$(make_directory_in_prefix 'state')"
xdg_runtime_directory="$(make_directory_in_prefix 'runtime')"
xdg_cache_directory="$(make_directory_in_prefix 'cache')"

# Some packages need one of their XDG Base directories to be mutable so if the
# Nix store isn't writable we copy the directories into temporary ones.
activation_package_config_directory="${ACTIVATION_PACKAGE:?}/home-files/.config"
activation_package_data_directory="$ACTIVATION_PACKAGE/home-files/.local/share"
if ! [[ -w $ACTIVATION_PACKAGE ]]; then
  xdg_config_directory="$(make_directory_in_prefix config)"
  xdg_data_directory="$(make_directory_in_prefix data)"
  cp --no-preserve=mode --recursive --dereference \
    "$activation_package_config_directory"/* "$xdg_config_directory"
  cp --no-preserve=mode --recursive --dereference \
    "$activation_package_data_directory"/* "$xdg_data_directory"
else
  xdg_config_directory="$activation_package_config_directory"
  xdg_data_directory="$activation_package_data_directory"

  # This way we have a reference to all the XDG base directories from the prefix
  config_in_prefix="$(make_directory_in_prefix 'config')"
  ln --symbolic "$xdg_config_directory" "$config_in_prefix"
  data_in_prefix="$(make_directory_in_prefix 'data')"
  ln --symbolic "$xdg_data_directory" "$data_in_prefix"
fi

xdg_env_vars=(
  XDG_CONFIG_HOME="$xdg_config_directory"
  XDG_DATA_HOME="$xdg_data_directory"
  XDG_STATE_HOME="$xdg_state_directory"
  XDG_RUNTIME_DIR="$xdg_runtime_directory"
  XDG_CACHE_HOME="$xdg_cache_directory"
)
set_xdg_env=(
  export
  "${xdg_env_vars[@]}"
)
set_xdg_env_escaped="$(printf '%q ' "${set_xdg_env[@]}")"

function add_directory_to_path {
  local directory="$1"
  local new_directory_basename="$2"

  new_directory="$(make_directory_in_prefix "$new_directory_basename")"
  for program in "$directory"/*; do
    program_basename="$(basename "$program")"

    case "$program_basename" in
      env)
        # Wrapping this caused an infinite loop so I'll copy it instead. I
        # guess the interpreter I was using in the shebang was calling env
        # somehow.
        cp -L "$program" "$new_directory/env"
        ;;
      fish)
        # I unexport the XDG Base directories so host programs pick up the host's XDG
        # directories.
        printf >"$new_directory/$program_basename" '%s' "#!${BASH_PATH:?}
$set_xdg_env_escaped
exec $program \
  --init-command 'set --unexport XDG_CONFIG_HOME' \
  --init-command 'set --unexport XDG_DATA_HOME' \
  --init-command 'set --unexport XDG_STATE_HOME' \
  --init-command 'set --unexport XDG_RUNTIME_DIR' \
  --init-command 'set --unexport XDG_CACHE_HOME' \
  \"\$@\""
        ;;
      nvim)
        # I unexport the XDG Base directories so host programs pick up the host's XDG
        # directories.
        printf >"$new_directory/$program_basename" '%s' "#!$BASH_PATH
$set_xdg_env_escaped
exec $program \
  -c 'unlet \$XDG_CONFIG_HOME' \
  -c 'unlet \$XDG_DATA_HOME' \
  -c 'unlet \$XDG_STATE_HOME' \
  -c 'unlet \$XDG_RUNTIME_DIR' \
  -c 'unlet \$XDG_CACHE_HOME' \
  \"\$@\""
        ;;
      *)
        printf >"$new_directory/$program_basename" '%s' "#!$BASH_PATH
$set_xdg_env_escaped
exec $program \"\$@\""
        ;;
    esac

    chmod +x "$new_directory/$program_basename"
  done

  export PATH="$new_directory:$PATH"
}

add_directory_to_path "$ACTIVATION_PACKAGE/home-path/bin" 'bin'
add_directory_to_path "$ACTIVATION_PACKAGE/home-files/.local/bin" 'bin-local'
export XDG_DATA_DIRS="${XDG_DATA_DIRS+${XDG_DATA_DIRS}:}$ACTIVATION_PACKAGE/home-path/share"
export PORTABLE_HOME='true'
shell="$(which "${USER_SHELL:?}")"
export SHELL="$shell"

if [[ -n ${INIT_SNIPPET:-} ]]; then
  xdg_var_names=()
  for var in "${xdg_env_vars[@]}"; do
    xdg_var_names+=("${var%=*}")
  done

  old_values=()
  for name in "${xdg_var_names[@]}"; do
    old_values+=("${!name:-}")
  done

  "${set_xdg_env[@]}"
  eval "$INIT_SNIPPET"

  for index in "${!xdg_var_names[@]}"; do
    name="${xdg_var_names[$index]}"
    old_value="${old_values[$index]}"
    declare -x "$name"="$old_value"
  done
fi

# WARNING: don't exec so our cleanup function can run
"$SHELL" "$@"
