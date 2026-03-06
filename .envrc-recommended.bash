source direnv/plugins/direnv-manual-reload.bash
direnv_manual_reload
source direnv/plugins/devshell-direnv.bash
DEVSHELL_DIRENV_FALLBACK=true use_devshell --file . devShells.development
