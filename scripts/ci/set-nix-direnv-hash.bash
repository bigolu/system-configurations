#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.direnv --command bash

# shellcheck shell=bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

# TODO: The following vs code bash debugger extension does not support bash_rematch:
# https://github.com/rogalmic/vscode-bash-debug/issues/183
# Also bash_rematch is more error prone since it has global state. I should use
# something else.

original_envrc="$(<.envrc)"
regex='.*source_url ['\''"](https://raw.githubusercontent.com/nix-community/nix-direnv/.*/direnvrc.*)['\''"] ['\''"][^[:space:]]+['\''"].*'
if ! [[ "$original_envrc" =~ $regex ]]; then
  echo 'Error: Could not find the direnv dependency statement' >&2
  exit 1
fi
nix_direnv_url="${BASH_REMATCH[1]}"

new_nix_direnv_hash="$(direnv fetchurl "$nix_direnv_url")"

new_envrc=
replacement_regex='(.*source_url ['\''"]https://raw.githubusercontent.com/nix-community/nix-direnv/.*/direnvrc.*['\''"] ['\''"])[^[:space:]]+(['\''"].*)'
if ! [[ "$original_envrc" =~ $replacement_regex ]]; then
  echo 'Error: Could not find the direnv url' >&2
  exit 1
fi
new_envrc="${BASH_REMATCH[1]}${new_nix_direnv_hash}${BASH_REMATCH[2]}"

echo "$new_envrc" >.envrc
