#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.gitMinimal --command bash

# shellcheck shell=bash

set -o errexit
set -o nounset
set -o pipefail

function main {
  diff_before_running="$(diff_including_untracked)"
  "$@"
  diff_after_running="$(diff_including_untracked)"

  if [ "$diff_before_running" != "$diff_after_running" ]; then
    return 1
  else
    return 0
  fi
}

function diff_including_untracked {
  readarray -d '' untracked_files < <(git ls-files -z --others --exclude-standard)
  track_files "${untracked_files[@]}"
  git diff
  untrack_files "${untracked_files[@]}"
}

function track_files {
  for file in "$@"; do
    git add --intent-to-add -- "$file"
  done
}

function untrack_files {
  for file in "$@"; do
    git reset --quiet -- "$file"
  done
}

main "$@"
