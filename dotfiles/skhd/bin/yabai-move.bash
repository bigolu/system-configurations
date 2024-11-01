#!/usr/bin/env bash

set -o errexit
shopt -s inherit_errexit
set -o nounset
set -o pipefail
shopt -s nullglob

function main {
  direction="$1"
  # window is not in a stack
  if yabai -m query --windows --window | jq --exit-status '."stack-index" == 0' 1>/dev/null 2>&1; then
    window_move "$direction"
  # window is in a stack
  else
    current_window_id="$(yabai -m query --windows --window | jq --raw-output '.id')"
    first_window_id="$(yabai -m query --windows --window stack.first | jq --raw-output '.id')"
    last_window_id="$(yabai -m query --windows --window stack.last | jq --raw-output '.id')"

    # window is first in the stack
    if [[ "$current_window_id" = "$first_window_id" ]]; then
      if [[ "$direction" = up ]]; then
        window_move "$direction"
      else
        stack_move "$direction"
      fi
    # window is last in the stack.
    elif [[ "$current_window_id" = "$last_window_id" ]]; then
      if [[ "$direction" = down ]]; then
        window_move "$direction"
      else
        stack_move "$direction"
      fi
    # window is somewhere in the middle of the stack
    else
      stack_move "$direction"
    fi
  fi
}

function stack_move {
  direction="$1"
  if [[ "$direction" = down ]]; then
    # If there's no next window in the stack, wrap around.
    yabai -m window --focus stack.next || yabai -m window --focus stack.first
  else
    # If there's no previous window in the stack, wrap around.
    yabai -m window --focus stack.prev || yabai -m window --focus stack.last
  fi
}

function window_move {
  direction="$1"
  if [[ "$direction" = down ]]; then
    yabai -m window --focus south
  else
    yabai -m window --focus north
  fi
}

main "$@"
