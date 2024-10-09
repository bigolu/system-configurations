#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

function main {
  key="$(paste)"
  clear_clipboard

  SOPS_AGE_KEY_FILE=/dev/stdin sops "$@" <<<"$key"
}

function clear_clipboard {
  : | pbcopy
}

function paste {
  if uname | grep -q Linux; then
    wl-paste
  else
    pbpaste
  fi
}

main "$@"
