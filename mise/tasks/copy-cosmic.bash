#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter rsync]"
#USAGE arg "<destination>" {
#USAGE   choices "to-repo" "to-system"
#USAGE }

# TODO: Regarding the choices above: I prefixed them to 'to-' so it's clear from the
# autocomplete menu that you're choosing the destination. You can specify a
# description for each autocomplete entry[1], but I get an error whenever I try. I
# should report an issue.
#
# [1]: https://usage.jdx.dev/spec/reference/complete#descriptions

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

case "${usage_destination:?}" in
  'to-repo')
    rsync --recursive ~/.config/cosmic/ dotfiles/cosmic/config/
    ;;
  'to-system')
    rsync --recursive dotfiles/cosmic/config/ ~/.config/cosmic/
    ;;
  *)
    # It shouldn't ever reach this case
    exit 1
    ;;
esac
