# Environment Variables
#   NIX_DEV_SHELL (required):
#     The name of the flake dev shell to load.

function main {
  source direnv/plugins/direnv-utils.bash
  # This should run first. The reason for this is in a comment at the top of the
  # function.
  direnv_manual_reload
  direnv_init_layout_directory

  dotenv_if_exists secrets.env

  set_up_nix
}

function set_up_nix {
  load_nix_config_file "${PWD}/nix/nix.conf"

  # renovate: nix-direnv
  source_url \
    'https://raw.githubusercontent.com/nix-community/nix-direnv/3.0.7/direnvrc' \
    'sha256-bn8WANE5a91RusFmRI7kS751ApelG02nMcwRekC/qzc='
  enable_nix_direnv_shell_diff
  use flake ".#${NIX_DEV_SHELL:?}"
}

# TODO: This wouldn't be necessary if nix supported project/directory-specific config
# files[1]. The `nixConfig` field on a flake isn't a good alternative because it only
# supports flakes so it doesn't apply to nix shebang scripts for example.
#
# https://github.com/NixOS/nix/issues/10258
function load_nix_config_file {
  local -r config_file="$1"
  add_line_to_nix_config "include ${config_file}"
}

function add_line_to_nix_config {
  local -r line="$1"

  local new_config
  if [[ -z ${NIX_CONFIG:-} ]]; then
    new_config="$line"
  else
    new_config="$NIX_CONFIG"$'\n'"$line"
  fi

  export NIX_CONFIG="$new_config"
}

function enable_nix_direnv_shell_diff {
  # Backup the original `use_flake`
  local original_function
  original_function="$(declare -f use_flake)"
  # Remove the first line, which contains the function name
  local -r original_function_without_name="${original_function#*$'\n'}"
  eval "original_use_flake()"$'\n'"$original_function_without_name"

  function use_flake {
    local old_dev_shell
    old_dev_shell="$(get_dev_shell_store_path)"

    original_use_flake "$@"

    local new_dev_shell
    new_dev_shell="$(get_dev_shell_store_path)"

    if [[ $old_dev_shell != "$new_dev_shell" ]]; then
      # TODO: fallback to nix store diff-closures if the nix version is high enough
      if type -P nvd >/dev/null; then
        nvd --color=never diff "$old_dev_shell" "$new_dev_shell"
      fi
    fi
  }
}

function get_dev_shell_store_path {
  # We have to use a list since there could be multiple matches for the glob, though
  # we're only expecting one match.
  local -ra profile_rc_list=(.direnv/flake-profile-*.rc)
  local -r profile_rc="${profile_rc_list[0]}"
  # Remove extension
  local -r profile="${profile_rc%.*}"
  if [[ -e $profile ]]; then
    realpath "$profile"
  fi
}

main
