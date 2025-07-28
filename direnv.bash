# Environment Variables
#   NIX_DEV_SHELL (optional):
#     The name of the dev shell to load.

source direnv/plugins/direnv-utils.bash
# This should run first. The reason for this is in a comment at the top of the
# function.
direnv_manual_reload
direnv_init_layout_directory

dotenv_if_exists secrets.env

source direnv/plugins/nix-direnv-wrapper.bash
if [[ ${CI:-} == 'true' ]]; then
  default='ci-essentials'
  export NIX_DIRENV_DISABLE_NPINS_GC_ROOTS='true'
else
  default='development'
fi
use nix -A "devShells.${NIX_DEV_SHELL:-$default}"
