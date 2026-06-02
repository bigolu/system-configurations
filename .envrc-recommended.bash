source direnv/plugins/direnv-manual-reload.bash
direnv_manual_reload

source direnv/plugins/devshell-direnv.bash
DEVSHELL_DIRENV_FALLBACK=true use_devshell --file . devShells.development

source_url \
	'https://raw.githubusercontent.com/bigolu/direnv-autocomplete/7505862f80b5501977757686a2219475d8bde3e7/src/main.bash' \
	'sha256-VeqqJ67/ZRbbhQ9T8ngSziyTh2+B2GwoH7XYwTbxAlI='
