{
  lib,
  pkgs,
  isGui,
  ...
}:
let
  inherit (lib) optionalAttrs optionals;
  inherit (pkgs.stdenv) isLinux;
  isLinuxGui = isLinux && isGui;
in
optionalAttrs isGui {
  home.packages =
    with pkgs;
    optionals isLinuxGui [
      ghostty
    ];

  repository.symlink.xdg.configFile =
    {
      "ghostty/config".source = "ghostty/config";
      "ghostty/themes".source = "ghostty/themes";
    }
    // optionalAttrs isLinux {
      "ghostty/linux-config".source = "ghostty/linux-config";
    };
}
