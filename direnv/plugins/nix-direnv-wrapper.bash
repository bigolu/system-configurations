# A wrapper for nix-direnv that provides the following additional features:
#   - Show a diff of the dev shell when it changes

# renovate: nix-direnv
source_url \
  'https://raw.githubusercontent.com/nix-community/nix-direnv/3.0.7/direnvrc' \
  'sha256-bn8WANE5a91RusFmRI7kS751ApelG02nMcwRekC/qzc='

function _ndw_create_wrappers {
  _ndw_create_wrapper 'use_nix'
  _ndw_create_wrapper 'use_flake'
}

function _ndw_create_wrapper {
  local -r function_name="$1"

  _ndw_backup "$function_name"
  eval "
    function $function_name {
      _ndw_wrapper $function_name \"\$@\"
    }
  "
}

function _ndw_backup {
  local -r function_name="$1"

  local original_function
  original_function="$(declare -f "$function_name")"
  # Remove the first line, which contains the function name
  local -r original_function_without_name="${original_function#*$'\n'}"
  eval "_ndw_original_${function_name}()"$'\n'"$original_function_without_name"
}

function _ndw_wrapper {
  local -r original_function_name="$1"
  local -ra args=("${@:2}")

  local profile_prefix
  if [[ $original_function_name == 'use_nix' ]]; then
    profile_prefix='nix'
  else
    profile_prefix='flake'
  fi
  profile_prefix="${profile_prefix}-profile"

  local old_dev_shell
  old_dev_shell="$(_ndw_get_dev_shell_store_path "$profile_prefix")"

  "_ndw_original_$original_function_name" "${args[@]}"

  local new_dev_shell
  new_dev_shell="$(_ndw_get_dev_shell_store_path "$profile_prefix")"

  if
    [[ $old_dev_shell != "$new_dev_shell" ]] &&
      # `old_dev_shell` won't exist the first time this runs
      [[ -n $old_dev_shell ]]
  then
    # TODO: fallback to nix store diff-closures if the nix version is high enough
    if type -P nvd >/dev/null; then
      nvd --color=never diff "$old_dev_shell" "$new_dev_shell"
    fi
  fi
}

function _ndw_get_dev_shell_store_path {
  local -r profile_prefix="$1"

  # Sometimes there can be more than one, but they'll both point to the same store
  # path.
  local -ra profile_rcs=("${direnv_layout_dir:-.direnv}/${profile_prefix}-"*.rc)
  if ((${#profile_rcs[@]} > 0)); then
    local -r profile_rc="${profile_rcs[0]}"
    # Remove extension
    local -r profile="${profile_rc%.*}"
    if [[ -e $profile ]]; then
      realpath "$profile"
    fi
  fi
}

_ndw_create_wrappers
