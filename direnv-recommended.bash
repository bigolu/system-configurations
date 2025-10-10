source direnv/plugins/direnv-manual-reload.bash
direnv_manual_reload

source direnv/plugins/minimal-nix-direnv.bash
if [[ ${CI:-} == 'true' ]]; then
  default='ci-essentials'
else
  default='development'
fi
# This has to be after `direnv_manual_reload`. See the source code for
# `direnv_manual_reload` to learn why.
use_nix dev_shell --file . "devShells.${NIX_DEV_SHELL:-$default}"

# TODO: Remove when lefthook v1.13.4 hits nixpkgs-unstable
PATH_add "$(direnv_layout_dir)/bin" || true
