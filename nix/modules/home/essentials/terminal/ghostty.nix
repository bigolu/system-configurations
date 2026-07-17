{
  lib,
  hasGui,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf;
in
mkIf hasGui {
  home.packages = [ pkgs.ghostty ];

  fileWrapper.xdg.configFile = {
    "ghostty/config.ghostty".source = "ghostty/config.ghostty";
    "ghostty/themes".source = "ghostty/themes";
  };
}
