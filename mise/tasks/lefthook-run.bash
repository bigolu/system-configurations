#! Though we don't use shebangs, cached-nix-shell expects the first line to be one so we put this on the first line instead.
#! nix-shell --keep NIX_PACKAGES
#! nix-shell -i nix-shell-interpreter
#! nix-shell --packages "with (import (builtins.getEnv \"NIX_PACKAGES\")); [nix-shell-interpreter]"
#MISE hide=true

# This is a wrapper for lefthook that sets the global file exclude list.
#
# TODO: Ideally, the global exclude list could be set inside the config file, this
# way I wouldn't need to make a wrapper.

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

lefthook \
  run \
  --exclude 'gozip/gomod2nix.toml' \
  --exclude '.vscode/ltex**' \
  --exclude 'dotfiles/keyboard/US keyboard - no accent keys.bundle/**' \
  --exclude 'dotfiles/cosmic/config/**' \
  --exclude 'docs/**' \
  "$@"
