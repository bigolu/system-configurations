#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

namespace='sops_age_key'
variable='SOPS_AGE_KEY'

function main {
  key="$(get_key_from_keychain)"

  if ! is_valid "$key"; then
    key="$(get_and_clear_clipboard)"
    if is_valid "$key"; then
      add_key_to_keychain "$key"
    else
      echo 'error: Invalid key' >&2
      exit 1
    fi
  fi

  run_sops_with_key "$key" "$@"
}

function run_sops_with_key {
  key="$1"
  shift
  SOPS_AGE_KEY_FILE=/dev/stdin sops "$@" <<<"$key"
}

function is_valid {
  # sops's exit codes and reasons for using each, are listed here[1], but none of
  # them quite fit my use case. I decided to use the code below based on my manual tests
  # of running sops with different types of invalid keys:
  #   - A string that doesn't have the right format
  #   - An empty string
  #   - A string with the wrong key, but the right format
  #  And in all cases it exited with 128
  #
  # [1]: https://github.com/getsops/sops/blob/365d9242f26b308bee98fae01057e57f2e67a1a8/cmd/sops/codes/codes.go
  invalid_key_exit_code=128

  set +o errexit
  run_sops_with_key "$1" decrypt ~/code/secrets/src/test.enc.env &>/dev/null
  exit_code=$?
  set -o errexit

  if ((exit_code == 0)); then
    return 0
  elif ((exit_code == invalid_key_exit_code)); then
    return 1
  else
    echo 'error: Unexpected exit code from sops, exiting.' >&2
    exit "$exit_code"
  fi
}

function add_key_to_keychain {
  # Suppressing stdout to hide envchain's prompt
  echo "$1" | envchain --set --require-passphrase "$namespace" "$variable" 1>/dev/null
}

function get_key_from_keychain {
  # If the namespace doesn't exist, printenv will fail, but I'm going to
  # suppress that failure and just return an empty string.
  #
  # I suppress stderr since envchain will print a warning message if the namespace does
  # not exist.
  envchain "$namespace" printenv "$variable" 2>/dev/null || true
}

function clear_clipboard {
  : | copy
}

function get_and_clear_clipboard {
  paste
  clear_clipboard
}

function copy {
  if uname | grep -q Linux; then
    wl-copy
  else
    pbcopy
  fi
}

function paste {
  if uname | grep -q Linux; then
    wl-paste
  else
    pbpaste
  fi
}

main "$@"
