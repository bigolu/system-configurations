{
  lib,
  hasGui,
  pkgs,
  ...
}:
let
  inherit (lib) optionalAttrs optionals;
in
{
  home.packages = with pkgs; optionals hasGui [ ghostty ];
  fileWrapper.xdg.configFile = optionalAttrs hasGui {
    "ghostty/config.ghostty".source = "ghostty/config.ghostty";
    "ghostty/themes".source = "ghostty/themes";
  };
}
