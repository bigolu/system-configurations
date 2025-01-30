#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# argument one should be a direction: east, west, north, south
(($# > 0))

other_stacked_window="$(yabai -m query --windows --window stack.prev 2>/dev/null || yabai -m query --windows --window stack.next 2>/dev/null)"
other_stacked_window_id="$(jq --raw-output '.id' <<<"$other_stacked_window")"
if [[ -z $other_stacked_window_id ]]; then
  exit 1
fi

# remove current window from stack
yabai -m window --toggle float

# Make the current window a managed window again, we can't warp it otherwise
yabai -m window --toggle float

# Set the split direction of the window we want to warp onto
yabai -m window "$other_stacked_window_id" --insert "$1"

yabai -m window --warp "$other_stacked_window_id"
