#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter coreutils]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

function main {
  local -r bundle_path="$(make_bundle)"
  assert_bundle_meets_size_limit "$bundle_path"

  local -r bundle_basename_with_platform="$(get_basename_with_platform "$bundle_path")"

  artifact_directory="$(mktemp --directory)"
  echo "artifact-directory=$artifact_directory" >>"${GITHUB_OUTPUT:-/dev/stdout}"

  checksum_directory="$artifact_directory/checksums"
  mkdir "$checksum_directory"
  get_checksum "$bundle_path" >"$checksum_directory/${bundle_basename_with_platform}.txt"

  asset_directory="$artifact_directory/assets"
  mkdir "$asset_directory"
  mv "$bundle_path" "${asset_directory}/${bundle_basename_with_platform}"
}

# Creates the bundle and prints its path
function make_bundle {
  # Redirect stdout to stderr until we're ready to print the bundle path
  exec {stdout_copy}>&1
  exec 1>&2

  # Enter a new directory so the only file in it will be the bundle. This way, I can
  # use the '*' glob to match the name of the bundle instead of hardcoding it.
  flake_path="$PWD"
  pushd "$(mktemp --directory)"

  # nix will create a symlink to the bundle in the current directory
  nix bundle --show-trace --bundler "${flake_path}#" "${flake_path}#shell"
  bundle_basename="$(echo *)"
  bundle_path="$PWD/$bundle_basename"
  dereference_symlink "$bundle_path"

  popd

  exec 1>&$stdout_copy

  echo "$bundle_path"
}

# Replace a symlink with a copy of the file that it points to
function dereference_symlink {
  local -r symlink_path="$1"

  temp="$(mktemp --directory)"
  cp --dereference "$symlink_path" "$temp/copy"
  rm "$symlink_path"
  mv "$temp/copy" "$symlink_path"
}

function get_checksum {
  local -r file="$1"
  shasum -a 256 "$file" | cut -d ' ' -f 1
}

function assert_bundle_meets_size_limit {
  local -r bundle_path="$1"

  size="$(du -m "$bundle_path" | cut -f1)"
  max_size=250
  if ((size > max_size)); then
    echo "Shell is too big: $size MB. Max size: $max_size"
    exit 1
  fi
}

function get_basename_with_platform {
  local -r file="$1"

  # e.g. x86_64-linux
  local -r platform="$(uname -m)-$(uname -s | tr '[:upper:]' '[:lower:]')"
  local -r basename="${file##*/}"
  echo "${basename}-${platform}"
}

main "$@"
