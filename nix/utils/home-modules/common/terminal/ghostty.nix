{
  lib,
  pkgs,
  hasGui,
  ...
}:
let
  inherit (lib) optionalAttrs;
  inherit (pkgs.stdenv) isLinux;
in
{
  repository.xdg.configFile = optionalAttrs hasGui (
    {
      "ghostty/config".source = "ghostty/config";
      "ghostty/themes".source = "ghostty/themes";
    }
    // optionalAttrs isLinux {
      "ghostty/linux-config".source = "ghostty/linux-config";
    }
  );
}
