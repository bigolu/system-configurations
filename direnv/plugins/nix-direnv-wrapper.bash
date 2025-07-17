# A wrapper for nix-direnv that provides the following additional features:
#   - Automatically load a nix config file
#   - Show a diff of the dev shell when it changes

# renovate: nix-direnv
source_url \
  'https://raw.githubusercontent.com/nix-community/nix-direnv/3.0.7/direnvrc' \
  'sha256-bn8WANE5a91RusFmRI7kS751ApelG02nMcwRekC/qzc='

function _ndw_create_wrappers {
  _ndw_original_use_nix_name='use_nix'
  _ndw_backup "$_ndw_original_use_nix_name"
  function use_nix {
    _ndw_wrapper_helper "$_ndw_original_use_nix_name" 'nix-profile' "$@"
  }

  _ndw_original_use_flake_name='use_flake'
  _ndw_backup "$_ndw_original_use_flake_name"
  function use_flake {
    _ndw_wrapper_helper "$_ndw_original_use_flake_name" 'flake-profile' "$@"
  }
}

function _ndw_make_gc_roots_for_npins {
  if
    [[ ${NIX_DIRENV_DISABLE_NPINS:-} == 'true' ]] ||
      ! type -P npins >/dev/null ||
      [[ ! -d npins && ! -d ${NPINS_DIRECTORY:-} ]]
  then
    return
  fi

  local -r directory="${direnv_layout_dir:-.direnv}/npins-gc-roots"
  if [[ ! -d $directory ]]; then
    mkdir -p "$directory"
  fi

  local output
  output="$(npins show)"
  local -a output_lines
  readarray -t output_lines <<<"$output"
  local -r pin_regex='^([^[:space:]].*): '
  local line
  for line in "${output_lines[@]}"; do
    if [[ $line =~ $pin_regex ]]; then
      local pin="${BASH_REMATCH[1]}"
      local pin_store_path
      pin_store_path="$(npins get-path "$pin")"
      local pin_store_path_base_name="${pin_store_path##*/}"
      nix build \
        --out-link "$directory/$pin_store_path_base_name" \
        "$pin_store_path"
    fi
  done
}

function _ndw_wrapper_helper {
  local -r original_function_name="$1"
  local -r profile_prefix="$2"
  local -ra args=("${@:3}")

  _ndw_load_nix_config_file

  local old_dev_shell
  old_dev_shell="$(_ndw_get_dev_shell_store_path "$profile_prefix")"

  "_ndw_original_$original_function_name" "${args[@]}"

  local new_dev_shell
  new_dev_shell="$(_ndw_get_dev_shell_store_path "$profile_prefix")"

  # `old_dev_shell` won't exist the first time this runs
  if [[ -n $old_dev_shell && ($old_dev_shell != "$new_dev_shell") ]]; then
    # TODO: fallback to nix store diff-closures if the nix version is high enough
    if type -P nvd >/dev/null; then
      nvd --color=never diff "$old_dev_shell" "$new_dev_shell"
    fi
  fi

  if [[ $original_function_name == 'use_nix' && ($old_dev_shell != "$new_dev_shell") ]]; then
    _ndw_make_gc_roots_for_npins
  fi
}

function _ndw_backup {
  local -r function_name="$1"

  local original_function
  original_function="$(declare -f "$function_name")"
  # Remove the first line, which contains the function name
  local -r original_function_without_name="${original_function#*$'\n'}"
  eval "_ndw_original_${function_name}()"$'\n'"$original_function_without_name"
}

# TODO: This wouldn't be necessary if nix supported project/directory-specific config
# files[1]. The `nixConfig` field on a flake isn't a good alternative because it only
# supports flakes so it doesn't apply to nix shebang scripts for example.
#
# https://github.com/NixOS/nix/issues/10258
function _ndw_load_nix_config_file {
  local config_file
  config_file="$(_ndw_find_nix_config_file)"
  if [[ -n $config_file ]]; then
    _ndw_add_line_to_nix_config "include $config_file"
  fi
}

function _ndw_find_nix_config_file {
  if [[ -n ${NIX_DIRENV_NIX_CONF:-} ]]; then
    echo "$NIX_DIRENV_NIX_CONF"
    return 0
  fi

  local relative_path
  local absolute_path
  for relative_path in 'nix.conf' 'nix/config.conf'; do
    if absolute_path="$(find_up "$relative_path")"; then
      echo "$absolute_path"
      return 0
    fi
  done
}

function _ndw_add_line_to_nix_config {
  local -r line="$1"

  local new_config
  if [[ -z ${NIX_CONFIG:-} ]]; then
    new_config="$line"
  else
    new_config="$NIX_CONFIG"$'\n'"$line"
  fi

  export NIX_CONFIG="$new_config"
}

function _ndw_get_dev_shell_store_path {
  local -r profile_prefix="$1"

  local -r profile_rc="$(echo ".direnv/${profile_prefix}-"*.rc)"
  # Remove extension
  local -r profile="${profile_rc%.*}"
  if [[ -e $profile ]]; then
    realpath "$profile"
  fi
}

_ndw_create_wrappers
