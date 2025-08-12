{
  pkgs,
  lib,
  name,
  ...
}:
let
  inherit (lib) optionals hasPrefix;
in
{
  stdenv = pkgs.stdenvNoCC;
  imports = optionals (hasPrefix "ci-" name) [ ./ci-essentials.nix ];
}
