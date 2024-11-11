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

  message=
  if ((size_diff != 0)); then
    if ((size_diff < 0)); then
      color="$green"
      sign=''
    else
      color="$red"
      sign='+'
    fi
    message="$(human_size "$size_before") → $(human_size "$size_after"), $color$sign$(human_size $size_diff)$reset"
  else
    message='Closure size is exactly the same'
  fi

  printf 'Total Size: %b\n' "$message"
}

function human_size {
  numfmt --to=iec-i --suffix=B --format="%.2f" -- "$1"
}

function get_closure_size {
  nix path-info --closure-size "$1" | awk '{ print $2 }'
}

main "$@"
