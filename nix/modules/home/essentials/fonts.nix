{
  lib,
  pkgs,
  hasGui,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isLinux;
  inherit (lib) optional;
in
{
  home.packages = optional hasGui pkgs.jetbrains-mono;
  fonts.fontconfig.enable = isLinux && hasGui;
}
