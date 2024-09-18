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

if uname | grep -q Linux; then
  sudo install \
    --compare \
    --owner=root --group=root --mode='u=rw,g=r,o=r' \
    -D \
    --verbose \
    --no-target-directory \
    "$script_directory/zz-nix-fix.fish" /usr/share/fish/vendor_conf.d/zz-nix-fix.fish
else
  # TODO: For some reason, if I give this script it's original name it comes
  # BEFORE nix.fish, but when I use "zzz" it comes AFTER.
  sudo install \
    --compare \
    --owner=root --group=admin --mode='u=rw,g=r,o=r' \
    -D \
    --verbose \
    --no-target-directory \
    "$script_directory/zz-nix-fix.fish" /usr/local/share/fish/vendor_conf.d/zzz.fish
fi
