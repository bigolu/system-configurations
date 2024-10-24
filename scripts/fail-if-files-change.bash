#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.gitMinimal --command bash

# When running locally, I need a way to tell if any of the checks modify files.
# Checks that may modify files include formatters, code generators, or lint fixers.
# This way, I can have a pre-push hook abort the push so I can fix up my commits.

# shellcheck shell=bash

set -o errexit
set -o nounset
set -o pipefail

# We only need to fail if files change when running locally for the reason given at
# the top of the file. In other environments, just run the specified command.
if [[ "${CI:-}" = 'true' ]]; then
  exec "$@"
fi

function main {
  diff_before_running="$(diff_including_untracked)"
  "$@"
  diff_after_running="$(diff_including_untracked)"

  if [[ "$diff_before_running" != "$diff_after_running" ]]; then
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
