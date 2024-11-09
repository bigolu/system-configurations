#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

red='\e[1;31m'
green='\e[1;32m'
reset='\e[0m'

function main {
  size_before=$(get_closure_size "$1")
  size_after=$(get_closure_size "$2")
  size_diff=$((size_after - size_before))

  if ((size_diff != 0)); then
    echo "Before: $(human_size "$size_before")"
    echo "After:  $(human_size "$size_after")"

    if ((size_diff < 0)); then
      color="$green"
      sign=''
    else
      color="$red"
      sign='+'
    fi
    printf 'Diff: %b%s%s%b\n' "$color" "$sign" "$(human_size $size_diff)" "$reset"
  else
    echo "Closure size is exactly the same"
  fi
}

function human_size {
  numfmt --to=iec-i --suffix=B --format="%.2f" -- "$1"
}

function get_closure_size {
  nix path-info --closure-size "$1" | awk '{ print $2 }'
}

main "$@"
