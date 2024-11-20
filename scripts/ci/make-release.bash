#! /usr/bin/env cached-nix-shell
#! nix-shell -i shebang-runner
#! nix-shell --packages shebang-runner coreutils gh
# ^ WARNING: Dependencies must be in this format to get parsed properly and added to
# dependencies.txt

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

tag='latest'

function main {
  delete_old_release
  make_new_release
}

function delete_old_release {
  gh release delete "$tag" --yes --cleanup-tag
}

function make_new_release {
  gh release create "$tag" \
    --latest \
    --notes-file "$(make_release_notes)" \
    --title "$(date +'%Y.%m.%d')" \
    artifacts/assets/*
}

function make_release_notes {
  notes_file="$(mktemp)"

  {
    printf '# SHA256 Checksums:\n\n'
    for checksum_file in artifacts/checksums/*; do
      base="$(basename "$checksum_file")"
      printf '%s\n' "${base%.*}"
      # shellcheck disable=2016
      printf '\n```\n%s\n```\n\n' "$(<"$checksum_file")"
    done
  } >"$notes_file"

  echo "$notes_file"
}

main
