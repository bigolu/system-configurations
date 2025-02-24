#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# `my-firefox` has to be on the PATH when `xdg-settings` is called
PATH="$HOME/.local/bin:$PATH"
# I tried to run this command in home-manager, but it didn't work.
xdg-settings set default-web-browser my-firefox.desktop
