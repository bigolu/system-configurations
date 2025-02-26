#!/usr/bin/env bash

# If Firefox Developer Edition is open, use that instead of normal firefox.

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

devedition_executable_name='firefox-devedition'

if pgrep --full "$devedition_executable_name" >/dev/null 2>&1; then
  exec "$devedition_executable_name" "$@"
else
  exec flatpak run org.mozilla.firefox "$@"
fi
