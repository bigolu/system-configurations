# Environment Variables
#   NIX_DEV_SHELL (required):
#     The name of the dev shell to load.

source direnv/plugins/direnv-utils.bash
# This should run first. The reason for this is in a comment at the top of the
# function.
direnv_manual_reload
direnv_init_layout_directory

dotenv_if_exists secrets.env

source direnv/plugins/nix-direnv-wrapper.bash
NIX_DIRENV_NIX_CONF="$PWD/nix/dev/nix.conf" use nix -A "devShells.${NIX_DEV_SHELL:?}"
