#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

clipboard_tool=
if uname | grep -q Linux; then
  clipboard_tool='wl-paste'
else
  clipboard_tool='pbpaste'
fi

"$clipboard_tool" | SOPS_AGE_KEY_FILE=/dev/stdin sops "$@"
