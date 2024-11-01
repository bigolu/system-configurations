#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.coreutils --command bash

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

reviewdog_flags=()
command_tokens=()
seen_delimiter=
for argument in "$@"; do
  if [[ "$seen_delimiter" = 1 ]]; then
    command_tokens=("${command_tokens[@]}" "$argument")
  elif [[ "$argument" = ':::' ]]; then
    seen_delimiter=1
  else
    reviewdog_flags=("${reviewdog_flags[@]}" "$argument")
  fi
done

"${command_tokens[@]}" | "$reviewdog" "${reviewdog_flags[@]}"
