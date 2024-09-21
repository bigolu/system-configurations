set -o errexit
set -o nounset
set -o pipefail

nix run .#homeManager -- switch --flake .#"$1"

./dotfiles/nix/set-locale-variable.bash
./dotfiles/nix/nix-fix/install-nix-fix.bash
./dotfiles/nix/systemd-garbage-collection/install.bash
./dotfiles/smart_plug/linux/install.bash
./dotfiles/linux/set-keyboard-to-mac-mode.sh
./dotfiles/keyd/install.bash
./dotfiles/firefox-developer-edition/set-default-browser.sh
