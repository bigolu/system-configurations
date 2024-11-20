#! /usr/bin/env cached-nix-shell
#! nix-shell -i shebang-runner
#! nix-shell --packages shebang-runner gnused
# ^ WARNING: Dependencies must be in this format to get parsed properly and added to
# dependencies.txt

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob

# shellcheck disable=2016
version="$(
  nix eval \
    --raw --impure --expr \
    '(import ./nixpkgs.nix {system = builtins.currentSystem;}).nix.version'
)"
sed --regexp-extended --in-place \
  "s/\/nix-[0-9]+(\.[0-9]+){0,2}/\/nix-$version/g" \
  .github/actions/setup/action.yml \
  README.md
