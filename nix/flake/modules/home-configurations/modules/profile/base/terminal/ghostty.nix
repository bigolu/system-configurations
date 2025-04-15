{
  lib,
  pkgs,
  isGui,
  ...
}:
let
  inherit (lib) optionalAttrs optionals;
  inherit (pkgs.stdenv) isLinux;
in
optionalAttrs isGui {
  home.packages = optionals isLinux [ pkgs.ghostty ];

  repository.xdg.configFile =
    {
      "ghostty/config".source = "ghostty/config";
      "ghostty/themes".source = "ghostty/themes";
    }
    // optionalAttrs isLinux {
      "ghostty/linux-config".source = "ghostty/linux-config";
    };
}
