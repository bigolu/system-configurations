#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.gh --command bash

# shellcheck shell=bash

set -o errexit
set -o nounset
set -o pipefail

function main {
  tag='latest'
  delete_old_release "$tag"
  make_new_release "$tag"
}

function delete_old_release {
  gh release delete "$1" --yes --cleanup-tag
}

function make_new_release {
  gh release create "$1" \
    --latest \
    --notes-file "$(make_release_notes)" \
    --title "$1" \
    artifacts/assets/*
}

function make_release_notes {
  notes_file="$(mktemp)"

  {
    printf '# SHA256 Checksums:\n\n'
    for checksum_file in artifacts/checksums/*; do
      printf '%s\n' "${checksum_file%.*}"
      # shellcheck disable=2016
      printf '\n```\n%s\n```\n\n' "$(<"$checksum_file")"
    done
  } >"$notes_file"

  echo "$notes_file"
}

main
