# A wrapper for nix-direnv that provides the following additional features:
#   - Automatically load a nix config file
#   - Show a diff of the dev shell when it changes

# renovate: nix-direnv
source_url \
  'https://raw.githubusercontent.com/nix-community/nix-direnv/3.0.7/direnvrc' \
  'sha256-bn8WANE5a91RusFmRI7kS751ApelG02nMcwRekC/qzc='

function _ndw_create_wrapper {
  _ndw_backup_use_flake

  function use_flake {
    _ndw_load_nix_config_file

    local old_dev_shell
    old_dev_shell="$(_ndw_get_dev_shell_store_path)"

    _ndw_original_use_flake "$@"

    local new_dev_shell
    new_dev_shell="$(_ndw_get_dev_shell_store_path)"

    # `old_dev_shell` won't exist the first time this runs
    if [[ -n $old_dev_shell && ($old_dev_shell != "$new_dev_shell") ]]; then
      # TODO: fallback to nix store diff-closures if the nix version is high enough
      if type -P nvd >/dev/null; then
        nvd --color=never diff "$old_dev_shell" "$new_dev_shell"
      fi
    fi
  }
}

function _ndw_backup_use_flake {
  local original_function
  original_function="$(declare -f use_flake)"
  # Remove the first line, which contains the function name
  local -r original_function_without_name="${original_function#*$'\n'}"
  eval "_ndw_original_use_flake()"$'\n'"$original_function_without_name"
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
  local -r profile_rc="$(echo .direnv/flake-profile-*.rc)"
  # Remove extension
  local -r profile="${profile_rc%.*}"
  if [[ -e $profile ]]; then
    realpath "$profile"
  fi
}

_ndw_create_wrapper
