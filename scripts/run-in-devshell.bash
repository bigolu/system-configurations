# Runs the given the command within the devShell. I could use
# `direnv exec "$PWD" ...`, but it took ~1.5 seconds to `git switch/checkout`.
# With this it takes ~500ms.

set -o errexit
set -o nounset
set -o pipefail

# shellcheck disable=1090
# TODO: Instead of sourcing this file created by nix-direnv I could create
# my own after the entire direnv environment is loaded. This way it would
# include things like secrets. Though I think some variables would require
# special handling:
# https://github.com/nix-community/nix-direnv/blob/41d7d45cae59b24cf0df1efb8881238ce0ed5906/direnvrc#L166
source .direnv/flake-profile*.rc
exec "$@"