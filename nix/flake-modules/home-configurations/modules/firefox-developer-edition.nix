{
  lib,
  pkgs,
  isGui,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux isDarwin;
  inherit (lib) mkIf mkMerge;

  linux = mkIf (isGui && isLinux) {
    repository.xdg = {
      executable."my-firefox".source = "firefox-developer-edition/my-firefox.bash";
      dataFile."applications/my-firefox.desktop" = {
        source = "firefox-developer-edition/my-firefox.desktop";
        # The system replaces my symlink with a regular file.
        force = true;
      };
    };
  };

  darwin = mkIf (isGui && isDarwin) {
    repository.home.file.".finicky.js".source = "firefox-developer-edition/finicky/finicky.js";
  };
in
mkMerge [
  linux
  darwin
]
