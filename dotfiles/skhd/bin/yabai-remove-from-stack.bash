#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

# argument one should be a direction: east, west, north, south
(($# > 0))

OTHER_STACKED_WINDOW_ID="$(printf %s "$(yabai -m query --windows --window stack.prev 2>/dev/null || yabai -m query --windows --window stack.next 2>/dev/null)" | jq --raw-output '.id')"
if [[ -z "${OTHER_STACKED_WINDOW_ID:-}" ]]; then
  exit 1
fi

# remove current window from stack
yabai -m window --toggle float

# Make the current window a managed window again, we can't warp it otherwise
yabai -m window --toggle float

# Set the split direction of the window we want to warp onto
yabai -m window "$OTHER_STACKED_WINDOW_ID" --insert "$1"

yabai -m window --warp "$OTHER_STACKED_WINDOW_ID"
