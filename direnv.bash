# Environment Variables
#   NIX_DEV_SHELL (optional):
#     The name of the dev shell to load.

# This should run first. The reason for this is in a comment at the top of the
# function.
source direnv/plugins/direnv-manual-reload.bash
direnv_manual_reload

dotenv_if_exists

source direnv/plugins/minimal-nix-direnv.bash
if [[ ${CI:-} == 'true' ]]; then
  default='ci-essentials'
else
  default='development'
fi
use nix devshell --file . "devShells.${NIX_DEV_SHELL:-$default}"
