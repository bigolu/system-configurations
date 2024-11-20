#! /usr/bin/env cached-nix-shell
#! nix-shell -i shebang-runner
#! nix-shell --packages shebang-runner coreutils
# ^ WARNING: Dependencies must be in this format to get parsed properly and added to
# dependencies.txt

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

nix bundle --show-trace --bundler .# .#shell

# The symlink's names will look like 'shell-<platform>', e.g.
# shell-x86_64-linux, so I'm using a glob pattern to match it.
shell_name="$(echo shell-*)"
artifact_directory="$(mktemp --directory)"

asset_directory="$artifact_directory/assets"
mkdir "$asset_directory"
shell_path="$asset_directory/$shell_name"
# Dereference the symlink so I can upload the actual executable.
cp --dereference "$shell_name" "$shell_path"

size="$(du -m "$shell_path" | cut -f1)"
max_size=250
if ((size > max_size)); then
  echo "Shell is too big: $size MB. Max size: $max_size"
  exit 1
fi

checksum_directory="$artifact_directory/checksums"
mkdir "$checksum_directory"
shasum -a 256 "$shell_path" | cut -d ' ' -f 1 >"$checksum_directory/$shell_name.txt"

echo "artifact-directory=$artifact_directory" >>"$GITHUB_OUTPUT"
