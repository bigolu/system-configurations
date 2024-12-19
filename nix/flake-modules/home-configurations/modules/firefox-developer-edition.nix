{
  lib,
  pkgs,
  config,
  isGui,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux isDarwin;
  inherit (lib) mkIf mkMerge hm;

  linux = mkIf (isGui && isLinux) {
    repository.symlink.xdg.executable."my-firefox".source = "firefox-developer-edition/my-firefox.bash";

    # The system replaces my symlink with a regular file and Home Manager doesn't
    # support backups on flake-based configs so I'll emulate that here.
    home.activation.installBrowserDesktopFile = hm.dag.entryAfter [ "writeBoundary" ] ''
      source=${config.repository.directory}/dotfiles/firefox-developer-edition/my-firefox.desktop
      destination=${config.xdg.dataHome}/applications/my-firefox.desktop
      if [[ ! -e "$destination" ]]; then
        mkdir -p "$(dirname "$destination")"
        ln --symbolic --force --no-dereference "$source" "$destination"
      fi
    '';
  };

  darwin = mkIf (isGui && isDarwin) {
    repository.symlink.home.file.".finicky.js".source = "firefox-developer-edition/finicky/finicky.js";
  };
in
mkMerge [
  linux
  darwin
]
