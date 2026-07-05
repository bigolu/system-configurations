{
  lib,
  pkgs,
  hasGui,
  ...
}:
let
  inherit (lib) optionalAttrs;
  inherit (pkgs.stdenv.hostPlatform) isLinux;
in
{
  fileWrapper.xdg.configFile = optionalAttrs hasGui (
    {
      "ghostty/config.ghostty".source = "ghostty/config.ghostty";
      "ghostty/themes".source = "ghostty/themes";
    }
    // optionalAttrs isLinux { "ghostty/linux-config.ghostty".source = "ghostty/linux-config.ghostty"; }
  );
}
