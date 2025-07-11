#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter coreutils]"
#MISE hide=true

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
  local flake_path="$PWD"
  local temp_directory
  temp_directory="$(mktemp --directory)"
  pushd "$temp_directory"

  # nix will create a symlink to the bundle in the current directory
  nix bundle --bundler "${flake_path}#" "${flake_path}#shell"
  local bundle_basename
  bundle_basename="$(echo *)"
  local bundle_symlink_path="$PWD/$bundle_basename"
  local bundle_path
  bundle_path="$(dereference_symlink "$bundle_symlink_path")"

  popd

  exec 1>&$stdout_copy
  echo "$bundle_path"
}

function dereference_symlink {
  local -r symlink_path="$1"
  local -r symlink_basename="${symlink_path##*/}"

  local dereferenced
  # Don't overwrite the symlink since it's a GC root
  dereferenced="$(mktemp --directory)/$symlink_basename"
  cp --dereference "$symlink_path" "$dereferenced"

  echo "$dereferenced"
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

  local -r basename="${file##*/}"

  # e.g. x86_64-linux
  local platform
  platform="$(uname -ms)"
  platform="${platform,,}"
  platform="${platform// /-}"

  echo "${basename}-${platform}"
}

main "$@"
