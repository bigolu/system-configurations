#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# Prints a cheatsheet for fzf keybinds.
#
# Additional keybinds can be set in the FZF_HINTS environment variable, separated by
# '\n', in the format '<keybind>: <description>'. This way you can add keybinds
# specific to an fzf invocation.
#
# Usage:
# FZF_HINTS='ctrl+a: additional binding' fzf --preview fzf-help-preview

function main {
  navigation="$(
    make_hint_section \
      'Navigation' \
      'shift+tab/tab: move up/down' \
      'alt+enter: select multiple items' \
      'ctrl-t: toggle tracking' \
      'alt-w: toggle wrap'
  )"

  history="$(
    make_hint_section \
      'History' \
      'ctrl+[/]: go to previous/next entry in history'
  )"

  preview_window="$(
    make_hint_section \
      'Preview Window' \
      'ctrl+s: show selected entries' \
      'ctrl+p: toggle preview visibility' \
      'ctrl+r: refresh preview' \
      'ctrl+k/j: scroll preview window up/down one line' \
      'ctrl+w: toggle line wrap' \
      'ctrl+o: toggle preview window orientation'
  )"

  search_syntax="$(
    make_hint_section \
      'Search Syntax' \
      \''<query>: exact match' \
      '^<query>: prefix match' \
      '<query>$: suffix match' \
      '!<query>: inverse exact match' \
      '!^<query>: inverse prefix exact match' \
      '!<query>$: inverse suffix exact match' \
      '<query1> <query2>: match all queries' \
      '<query1> | <query2>: match any query'
  )"

  default_hint_sections=(
    "${navigation[@]}"
    "${history[@]}"
    "${preview_window[@]}"
    "${search_syntax[@]}"
  )

  hint_sections=("${default_hint_sections[@]}")
  if [[ -n ${FZF_HINTS:-} ]]; then
    readarray -t widget_specific_hints < <(echo -e "$FZF_HINTS")
    widget_specific_hint_section="$(make_hint_section 'Widget-Specific' "${widget_specific_hints[@]}")"

    hint_sections=(
      "$widget_specific_hint_section"
      "${hint_sections[@]}"
    )
  fi

  join $'\n\n' "${hint_sections[@]}"
}

function make_hint_section {
  section_name="$1"
  hints=("${@:2}")

  highlighted_hints="$(printf '%s\n' "${hints[@]}" | rg --color always '(^.*:)')"
  echo -e "\e[1m$section_name"$'\n'"$highlighted_hints"
}

# source: https://stackoverflow.com/a/17841619
function join {
  local d=${1-} f=${2-}
  if shift 2; then
    printf %s "$f" "${@/#/$d}"
  fi
}

main
