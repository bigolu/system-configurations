{
  lib,
  pkgs,
  specialArgs,
  config,
  ...
}:
let
  inherit (specialArgs) isGui;
  inherit (pkgs.stdenv) isLinux isDarwin;

  linux = lib.mkIf (isGui && isLinux) {
    repository.symlink.xdg.executable."my-firefox".source = "firefox-developer-edition/my-firefox.bash";

    home.activation.installBrowserDesktopFile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # Add /usr/bin so scripts can access system programs like sudo/apt
      PATH="$PATH:/usr/bin"

      source=${config.repository.directory}/dotfiles/firefox-developer-edition/my-firefox.desktop
      destination=${config.xdg.dataHome}/applications/my-firefox.desktop
      if [[ ! -e "$destination" ]]; then
        sudo mkdir -p "$(dirname "$destination")"
        sudo ln --symbolic --force --no-dereference "$source" "$destination"
      fi
    '';
  };

  darwin = lib.mkIf (isGui && isDarwin) {
    repository.symlink.home.file.".finicky.js".source = "firefox-developer-edition/finicky/finicky.js";
  };
in
lib.mkMerge [
  linux
  darwin
]
