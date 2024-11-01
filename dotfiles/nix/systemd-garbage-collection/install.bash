#!/usr/bin/env bash

set -o errexit
shopt -s inherit_errexit
set -o nounset
set -o pipefail
shopt -s nullglob

# source:
# https://stackoverflow.com/questions/4774054/reliable-way-for-a-bash-script-to-get-the-full-path-to-itself
script_directory="$(
  cd -- "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)"

sudo install --compare --backup --suffix=.bak --owner=root --group=root --mode='u=rwx,g=r,o=r' -D --verbose --no-target-directory "$script_directory/nix-garbage-collection.service" /etc/systemd/system/nix-garbage-collection.service
sudo install --compare --backup --suffix=.bak --owner=root --group=root --mode='u=rwx,g=r,o=r' -D --verbose --no-target-directory "$script_directory/nix-garbage-collection.timer" /etc/systemd/system/nix-garbage-collection.timer
sudo systemctl daemon-reload
sudo systemctl enable nix-garbage-collection.timer
sudo systemctl start nix-garbage-collection.timer
