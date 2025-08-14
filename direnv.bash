# Environment Variables
#   NIX_DEV_SHELL (optional):
#     The name of the dev shell to load.

source direnv/plugins/direnv-utils.bash
# This should run first. The reason for this is in a comment at the top of the
# function.
direnv_manual_reload
direnv_init_layout_directory

source direnv/plugins/minimal-nix-direnv.bash
if [[ ${CI:-} == 'true' ]]; then
  default='ci-essentials'
else
  default='development'
fi
use devshell --file . "devShells.${NIX_DEV_SHELL:-$default}"
