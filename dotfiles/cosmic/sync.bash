#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

x=3

if [[ $1 == 'repo' ]]; then
  
  
  rsync --recursive ~/.config/cosmic/ dotfiles/cosmic/config/
elif [[ $1 == 'system' ]]; then
  rsync --recursive dotfiles/cosmic/config/ ~/.config/cosmic/
else
  echo 'Invalid destination' >&2
  exit 1
fi
