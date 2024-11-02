#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.coreutils local#nixpkgs.gitMinimal --command bash

# shellcheck shell=bash

set -o errexit
shopt -s inherit_errexit
set -o nounset
set -o pipefail
shopt -s nullglob

# source:
# https://stackoverflow.com/questions/4774054/reliable-way-for-a-bash-script-to-get-the-full-path-to-itself
script_directory="$(
  cd -- "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)"
reviewdog="$script_directory/reviewdog.bash"
fail_if_files_change="$script_directory/fail-if-files-change.bash"

reviewdog_flags=()
command_tokens=()
seen_delimiter=
for argument in "$@"; do
  if [[ "$seen_delimiter" = 1 ]]; then
    command_tokens+=("$argument")
  elif [[ "$argument" = ':::' ]]; then
    seen_delimiter=1
  else
    reviewdog_flags+=("$argument")
  fi
done

if [[ "${CI:-}" = 'true' ]]; then
  "${command_tokens[@]}"

  if [ -n "$(git status --porcelain)" ]; then
    git diff \
      | "$reviewdog" -f=diff -f.diff.strip=1 "${reviewdog_flags[@]}"
    # Remove changes. I could drop the stash as well, but in the very unlikely event
    # that the CI variable is set when this script is run locally, I don't want to
    # permanently delete any changes.
    git stash --include-untracked
  fi
else
  "$fail_if_files_change" "${command_tokens[@]}"
fi
