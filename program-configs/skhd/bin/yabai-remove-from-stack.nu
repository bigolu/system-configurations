#!/usr/bin/env nu

def main [
	direction: string # east, west, north, or south
] {
  let other_stacked_window_id = try {
    yabai -m query --windows --window stack.prev | ignore --stderr
  } catch {
    yabai -m query --windows --window stack.next | ignore --stderr
  }
  | from json
  | if id not-in $in { exit 1 } else { $in.id }

  # remove current window from stack
  yabai -m window --toggle float

  # Make the current window a managed window again, we can't warp it otherwise
  yabai -m window --toggle float

  # Set the split direction of the window we want to warp onto
  yabai -m window $other_stacked_window_id --insert $direction

  yabai -m window --warp $other_stacked_window_id
}
