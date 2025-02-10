#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter coreutils gh perl]"

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

tag='latest'

function main {
  delete_old_release
  make_new_release
}

function delete_old_release {
  gh release delete "$tag" --yes --cleanup-tag
}

function make_new_release {
  local title
  title="$(date +'%Y.%m.%d')"

  local bundles=("assets/bundles/"*)

  local checksum_file
  checksum_file="$(mktemp --directory)/checksums.txt"
  shasum -a 256 "${bundles[@]}" >"$checksum_file"

  gh release create "$tag" \
    --latest \
    --notes-file .github/release_notes.md \
    --title "$title" \
    "${bundles[@]}" "$checksum_file"
}

main
