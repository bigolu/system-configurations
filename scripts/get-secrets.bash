#!/usr/bin/env nix
#! nix shell --quiet local#nixpkgs.bash local#nixpkgs.coreutils local#nixpkgs.jq --command bash

# shellcheck shell=bash

set -o errexit
set -o nounset
set -o pipefail

project_dir="$PWD"

temp="$(mktemp --directory)"
trap 'rm -rf $temp' SIGINT SIGTERM ERR EXIT
cd "$temp"

if test -z "${BWS_ACCESS_TOKEN:-}"; then
  printf 'Enter the service account token (or just press enter to cancel):'
  read -rs token
  test -z "$token" && exit
  export BWS_ACCESS_TOKEN="$token"
fi

# I need --impure to read the NIXPKGS_ALLOW_UNFREE environment variable
bws="$(NIXPKGS_ALLOW_UNFREE=1 nix shell --impure nixpkgs#bws --command which -- bws)"
PATH="$(dirname "$bws"):$PATH"

declare -A secrets_to_fetch=(
  ['b9e0fe3d-037c-4de9-a933-b1ee011abdfd']="$project_dir/.env"
  ['a45acbd3-45ac-43f1-96fd-b0f9015b6c2c']="$HOME/.cloudflared/a52a24f6-92ee-4dc5-b537-24bad84b7b1f.json"
)
declare -A secrets_to_commit
for bws_id in "${!secrets_to_fetch[@]}"; do
  destination="${secrets_to_fetch[$bws_id]}"
  temp_filename="$(printf '%s' "$destination" | tr '/' '%')"
  printf '%s' "$(bws secret get "$bws_id" | jq --raw-output '.value')" >"$temp_filename"
  secrets_to_commit["$temp_filename"]="$destination"
done

# Writing secrets now to ensure we only write secrets if we succeed in
# getting all of them
for temp_filename in "${!secrets_to_commit[@]}"; do
  destination="${secrets_to_commit[$temp_filename]}"
  mkdir -p "$(dirname "$destination")"
  mv "$temp_filename" "$destination"
done
