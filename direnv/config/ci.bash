# Environment Variables
#   NIX_DEV_SHELL (optional):
#     The name of the flake dev shell to load.

NIX_DEV_SHELL="${NIX_DEV_SHELL:-ci-essentials}" \
  NIX_DIRENV_DISABLE_NPINS=true \
  source direnv/config/base.bash
