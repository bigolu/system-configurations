#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# Prints a cheatsheet for fzf keybinds. This is intended to be used in a call to
# preview() in fzf.
#
# Additional keybinds can be set in the FZF_HINTS environment variable,
# separated by '\n', in the format '<keybind>: <description>' (The format
# must be followed for it to be styled correctly). e.g. FZF_HINTS='ctrl+a:
# accept\nctrl+b:back'. This way you can add keybinds specific to an fzf
# invocation.
#
# Usage:
# FZF_HINTS='ctrl+a: additional binding' fzf --preview fzf-help-preview
#
# TODO: The hints inside here should be taken out and passed inside
# FZF_HINTS. This way the script doesn't have my keybinds hardcoded in it.

function main {
  hint_sections=(
    "$(format_hint_section 'Navigation' 'shift+tab/tab: move up/down' 'alt+enter: select multiple items' 'ctrl-t: toggle tracking' 'alt-w: toggle wrap')"
    "$(format_hint_section 'History' 'ctrl+[/]: go to previous/next entry in history')"
    "$(format_hint_section 'Preview Window' 'ctrl+s: show selected entries' 'ctrl+p: toggle preview visibility' 'ctrl+r: refresh preview' 'ctrl+k/j: scroll preview window up/down one line' 'ctrl+w: toggle line wrap' 'ctrl+o: toggle preview window orientation')"
    "$(format_hint_section 'Search Syntax' \''<query>: exact match' '^<query>: prefix match' '<query>$: suffix match' '!<query>: inverse exact match' '!^<query>: inverse prefix exact match' '!<query>$: inverse suffix exact match' '<query1> <query2>: match all queries' '<query1> | <query2>: match any query')"
  )
  if [ -n "${FZF_HINTS:-}" ]; then
    widget_specific_hints="$(echo -e "$FZF_HINTS")"
    hint_sections=("$(format_hint_section 'Widget-Specific' "$widget_specific_hints")" "${hint_sections[@]}")
  fi

  printf '%s\n\n' "${hint_sections[@]}"
}

function format_hint_section {
  section_name="$1"
  shift
  readarray -t hints < <(printf '%s\n' "$@" | grep --color=always -E '(^.*:)')
  echo -e '\e[1m'"$section_name"$'\n'"$(join $'\n' "${hints[@]}")"
}

# source: https://stackoverflow.com/a/17841619
function join {
  local d=${1-} f=${2-}
  if shift 2; then
    printf %s "$f" "${@/#/$d}"
  fi
}

main
