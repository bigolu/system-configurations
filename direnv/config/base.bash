# Environment Variables
#   NIX_DEV_SHELL (required):
#     The name of the flake dev shell to load.

source direnv/plugins/direnv-utils.bash
# This should run first. The reason for this is in a comment at the top of the
# function.
direnv_manual_reload
direnv_init_layout_directory

dotenv_if_exists secrets.env

source direnv/plugins/nix-direnv-wrapper.bash
# Reasons for using `use nix` instead of `use flake` are in compat.nix. Another
# reason is that nix-direnv doesn't provide a way to disable the creation of GC roots
# for all flake inputs.
use nix nix/flake/compat.nix -A "currentSystem.devShells.${NIX_DEV_SHELL:?}"
