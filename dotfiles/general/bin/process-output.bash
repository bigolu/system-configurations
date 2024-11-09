#!/usr/bin/env bash

# Prints the output, both stdout and stderr, of a running process.
# On macOS you have to disable dtrace SIP restriction with `csrutil enable --without dtrace`

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

if (($# == 0)); then
  echo "Invalid usage. Correct usage: $(basename "$0") <pid>" >&2
  exit 1
fi

pid="$1"
if uname | grep -q Darwin; then
  sudo dtrace -p "$pid" -qn '
      syscall::write*:entry
      /pid == $target && (arg0 == 1 || arg0 == 2)/ {
        printf("%s", copyinstr(arg1, arg2));
      }
    '
else
  # TODO: Remove catp and use strace directly
  sudo "$(which catp)" "$pid"
fi
