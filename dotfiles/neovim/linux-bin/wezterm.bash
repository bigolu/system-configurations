#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

flatpak run org.wezfurlong.wezterm "$@"
