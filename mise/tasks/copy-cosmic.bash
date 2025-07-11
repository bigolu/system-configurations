#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages nix-shell-interpreter rsync
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

repo='dotfiles/cosmic/config/'
system="$HOME/.config/cosmic/"

case "${usage_destination:?}" in
  'to-repo')
    source="$system"
    destination="$repo"
    ;;
  'to-system')
    source="$repo"
    destination="$system"
    ;;
  *)
    # It shouldn't ever reach this case
    exit 1
    ;;
esac

rsync --recursive "$source" "$destination"
