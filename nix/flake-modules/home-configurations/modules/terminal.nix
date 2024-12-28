{
  lib,
  pkgs,
  isGui,
  ...
}:
let
  inherit (lib) optionalAttrs optionals;
  isLinuxGui = pkgs.stdenv.isLinux && isGui;
in
optionalAttrs isGui {
  home.packages =
    with pkgs;
    optionals isLinuxGui [
      ghostty
    ];

  repository.symlink.xdg.configFile = {
    "ghostty".source = "ghostty";
  };
}
