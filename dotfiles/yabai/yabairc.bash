#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# Calling this when I'm already in tiling mode might change the order of my
# windows, which I don't want, so I only set tiling mode if it isn't already set
layout="$(yabai -m config layout)"
if [[ $layout != 'bsp' ]]; then
  yabai -m config layout bsp
fi

# Remove existing signal handlers. The remove command will fail if there's
# nothhing to remove so keep running it until it fails.
while yabai -m signal --remove 0 1>/dev/null 2>&1; do true; done

yabai -m config auto_balance off
yabai -m config focus_follows_mouse autoraise
yabai -m config mouse_follows_focus on
yabai -m config window_origin_display cursor
yabai -m config window_opacity on
yabai -m config mouse_drop_action swap
yabai -m config window_zoom_persist off
yabai -m config window_gap 7

# All the macOS system GUIs e.g. System Preferences
yabai -m rule --add label=system app="^System .*$" title=".*" manage=off
# The installer GUI that comes up when you click a .dmg
yabai -m rule --add label=disk app="^DiskImages UI Agent$" title=".*" manage=off
yabai -m rule --add label=installer app="^Installer$" title=".*" manage=off
# progress bar for copying a file
yabai -m rule --add label=finder app="^Finder$" title="^Copy$" manage=off
yabai -m rule --add label=firefox app="^Firefox$" title="^Log in to your PayPal account$" manage=off

# Hide the stack indicators if the current window is maximized and not in a stack.
function hide_stackline {
  if
    yabai -m query --windows --window |
      jq --exit-status '."has-fullscreen-zoom" and ."stack-index" == 0' 1>/dev/null 2>&1
  then
    alpha=0
  else
    alpha=1
  fi
  hs -c "if stackline.config:get([[appearance.alpha]]) ~= $alpha then stackline.config:set([[appearance.alpha]], $alpha) end"
}
call_hide_stackline="$(declare -f hide_stackline)"$'\n''hide_stackline'
yabai -m signal --add label=hidestackline event=window_resized action="$call_hide_stackline"
