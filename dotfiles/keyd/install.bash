#!/usr/bin/env bash

# Exit the script if any command returns a non-zero exit code.
set -o errexit
# Exit the script if an undefined variable is referenced.
set -o nounset

# source: https://stackoverflow.com/a/4774063
script_directory="$(
  cd -- "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)"

sudo install --compare --backup --suffix=.bak --owner=root --group=root --mode='u=rwx,g=r,o=r' -D --verbose --no-target-directory "$script_directory/default.conf" /etc/keyd/default.conf
sudo keyd reload
