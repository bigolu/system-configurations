#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter coreutils]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

# This creates a symlink in the current directory to the bundle
nix bundle --show-trace --bundler .# .#shell

# The bundle's name will look like 'shell-<version>', e.g. shell-0.0.1, so I'm using
# a glob pattern to match it.
shell_name="$(echo shell-*)"

# e.g. x86_64-linux
platform="$(uname -m)-$(uname -s | tr '[:upper:]' '[:lower:]')"
shell_name_with_platform="${shell_name}-${platform}"

artifact_directory="$(mktemp --directory)"
asset_directory="$artifact_directory/assets"
mkdir "$asset_directory"
shell_asset_path="${asset_directory}/${shell_name_with_platform}"
# Dereference the symlink so I can upload the actual executable.
cp --dereference "$shell_name" "$shell_asset_path"

size="$(du -m "$shell_asset_path" | cut -f1)"
max_size=250
if ((size > max_size)); then
  echo "Shell is too big: $size MB. Max size: $max_size"
  exit 1
fi

checksum_directory="$artifact_directory/checksums"
mkdir "$checksum_directory"
shasum -a 256 "$shell_asset_path" | cut -d ' ' -f 1 >"$checksum_directory/${shell_name_with_platform}.txt"

echo "artifact-directory=$artifact_directory" >>"$GITHUB_OUTPUT"
