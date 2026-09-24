#!/usr/bin/env nu

def main [direction] {
  let is_window_in_stack = yabai -m query --windows --window | from json | $in.stack-index != 0
  if not $is_window_in_stack {
    window_move $direction
  } else {
    let current_window_id = yabai -m query --windows --window | from json | get id
    let first_window_id = yabai -m query --windows --window stack.first | from json | get id
    let last_window_id = yabai -m query --windows --window stack.last | from json | get id

    if $current_window_id == $first_window_id {

      # window is first in the stack
      if $direction == up {
        window_move $direction
      } else {
        stack_move $direction
      }
    } else if $current_window_id == $last_window_id {
      # window is last in the stack
      if $direction == down {
        window_move $direction
      } else {
        stack_move $direction
      }
    } else {
      stack_move $direction
    }
  }
}

def stack_move [direction] {
  if $direction == down {

    # If there's no next window in the stack, wrap around.
    try {
      yabai -m window --focus stack.next
    } catch {
      yabai -m window --focus stack.first
    }
  } else {
    # If there's no previous window in the stack, wrap around.
    try {
      yabai -m window --focus stack.prev
    } catch {
      yabai -m window --focus stack.last
    }
  }
}

def window_move [direction] {
  if $direction == down {
    yabai -m window --focus south
  } else {
    yabai -m window --focus north
  }
}
