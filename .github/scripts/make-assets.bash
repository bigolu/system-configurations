#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter coreutils]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

function main {
  local asset_directory
  asset_directory="$(register_asset_directory)"

  local bundle
  bundle="$(make_shell_bundle)"

  assert_bundle_meets_size_limit "$bundle"

  move_bundle_into_assets "$asset_directory" "$bundle"
}

function register_asset_directory {
  local asset_directory
  asset_directory="$(mktemp --directory)"
  echo "asset-directory=$asset_directory" >>"${GITHUB_OUTPUT:-/dev/stderr}"

  echo "$asset_directory"
}

# Creates a bundle for the shell and prints its path
function make_shell_bundle {
  # Redirect stdout to stderr until we're ready to print the bundle path
  exec {stdout_copy}>&1
  exec 1>&2

  # Enter a new directory so the only file in it will be the bundle. This way, I can
  # use the '*' glob to match the name of the bundle instead of hardcoding it.
  local flake_path
  flake_path="$PWD"
  local temp_directory
  temp_directory="$(mktemp --directory)"
  pushd "$temp_directory"

  # nix will create a symlink to the bundle in the current directory
  nix bundle --show-trace --bundler "${flake_path}#" "${flake_path}#shell"
  local bundle_basename
  bundle_basename="$(echo *)"
  local bundle_path
  bundle_path="$PWD/$bundle_basename"
  dereference_symlink "$bundle_path"

  popd

  exec 1>&$stdout_copy
  echo "$bundle_path"
}

# Replace a symlink with a copy of the file that it points to
function dereference_symlink {
  local -r symlink_path="$1"

  local temp
  temp="$(mktemp --directory)"
  cp --dereference "$symlink_path" "$temp/copy"
  mv "$temp/copy" "$symlink_path"
}

function move_bundle_into_assets {
  local -r asset_directory="$1"
  local -r bundle_file="$2"

  local bundle_basename_with_platform
  bundle_basename_with_platform="$(get_basename_with_platform "$bundle_file")"

  mv "$bundle_file" "${asset_directory}/${bundle_basename_with_platform}"
}

function assert_bundle_meets_size_limit {
  local -r bundle_file="$1"

  local -r max_size=350
  local size
  size="$(du -m "$bundle_file" | cut -f1)"
  if ((size > max_size)); then
    echo "Shell is too big: $size MB. Max size: $max_size"
    exit 1
  fi
}

# Example: a/b/file -> file-x86_64-linux
function get_basename_with_platform {
  local -r file="$1"

  # e.g. x86_64
  local instruction_set
  instruction_set="$(uname -m)"

  local kernel
  kernel="$(uname -s | tr '[:upper:]' '[:lower:]')"

  local -r platform="$instruction_set-$kernel"
  local -r basename="${file##*/}"

  echo "${basename}-${platform}"
}

main "$@"
