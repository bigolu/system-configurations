#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

# I tried to run this command in home-manager, but it doesn't work.
xdg-settings set default-web-browser my-firefox.desktop
