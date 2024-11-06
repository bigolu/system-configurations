#!/usr/bin/env bash

# I tried to make the config files symlinks, but COSMIC replaces them with regular
# files when I change a setting. Instead, I'll just occasionally sync.

# shellcheck shell=bash

set -o errexit
shopt -s inherit_errexit
set -o nounset
set -o pipefail
shopt -s nullglob

if [[ "$1" = 'repo' ]]; then
  rsync --recursive ~/.config/cosmic dotfiles/cosmic/config
elif [[ "$1" = 'system' ]]; then
  rsync --recursive dotfiles/cosmic/config ~/.config/cosmic
else
  echo 'Invalid destination' >&2
  exit 1
fi
