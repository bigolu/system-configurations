#! /usr/bin/env cached-nix-shell
#! nix-shell --keep FLAKE_PACKAGE_SET_FILE
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"FLAKE_PACKAGE_SET_FILE\")); [nix-shell-interpreter curl coreutils darwin-rebuild]"
#USAGE arg "<destination>" {
#USAGE   choices "to-repo" "to-sync"
#USAGE }

# TODO: Regarding the choices above: I prefixed them to 'to-' so it's clear from the
# autocomplete menu that you're choosing the destination. There's a mechanism for
# specifying a description for each autocomplete entry[1], but I get an error
# whenever I try to use it. I should report an issue.
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
