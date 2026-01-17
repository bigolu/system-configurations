source direnv/plugins/direnv-manual-reload.bash
direnv_manual_reload
source direnv/plugins/minimal-nix-direnv.bash
use_nix numtide_dev_shell --file . devShells.development
