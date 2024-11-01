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

group=
if uname | grep -q Linux; then
  group='root'
  prefix='/usr/share/fish/vendor_conf.d'
else
  group='admin'
  prefix='/usr/local/share/fish/vendor_conf.d'
fi

sudo install \
  --compare \
  --owner=root --group="$group" --mode='u=rw,g=r,o=r' \
  -D \
  --verbose \
  --no-target-directory \
  "$script_directory/zz-nix-fix.fish" "$prefix/zz-nix-fix.fish"
