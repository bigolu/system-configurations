{ lib, hasGui, ... }:
let
  inherit (lib) optionalAttrs;
in
{
  fileWrapper.xdg.configFile = optionalAttrs hasGui {
    "ghostty/config.ghostty".source = "ghostty/config.ghostty";
    "ghostty/themes".source = "ghostty/themes";
  };
}
