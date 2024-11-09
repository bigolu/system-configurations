#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.gitMinimal local#nixpkgs.lefthook --command bash

# shellcheck shell=bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

groups="$1"

lefthook_command=(lefthook run check)

if [[ "$groups" != 'all' ]]; then
  lefthook_command+=(--commands "$groups")
fi

# Arguments after the first one are passed on to lefthook
lefthook_command+=("${@:2}")

"${lefthook_command[@]}"
