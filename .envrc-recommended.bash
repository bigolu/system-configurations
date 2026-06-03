path="$(
	fetchurl \
		'https://raw.githubusercontent.com/bigolu/direnv-devshell/c063e0605481ec97cfec78abd8dd9ead0746318d/src/main.bash' \
		'sha256-J1DKZGjz/XiKz430g8pN5CZnqa7kyZ/RIlnV+rTufas='
)"
# shellcheck disable=1090
source "$path"
DEVSHELL_DIRENV_FALLBACK=true use_devshell --file . devShells.development

path="$(
	fetchurl \
		'https://raw.githubusercontent.com/bigolu/direnv-autocomplete/7505862f80b5501977757686a2219475d8bde3e7/src/main.bash' \
		'sha256-VeqqJ67/ZRbbhQ9T8ngSziyTh2+B2GwoH7XYwTbxAlI='
)"
# shellcheck disable=1090
source "$path"
