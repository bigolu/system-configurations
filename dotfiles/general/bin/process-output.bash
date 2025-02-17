#!/usr/bin/env bash

# Prints the output, both stdout and stderr, of a running process.
# On macOS you have to disable dtrace SIP restriction with `csrutil enable --without dtrace`

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

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
  strace="$(which strace)"
  sudo "$strace" \
    --attach "$pid" --follow-forks \
    --string-limit 9999999 \
    --signal '!all' --quiet=attach,exit \
    --trace=write --trace-fds=0,1,2
fi
