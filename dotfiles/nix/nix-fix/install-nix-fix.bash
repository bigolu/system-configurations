#!/usr/bin/env bash

# Exit the script if any command returns a non-zero exit code.
set -o errexit
# Exit the script if an undefined variable is referenced.
set -o nounset

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
