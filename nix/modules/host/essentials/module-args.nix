{
  type,
  hostName ? abort "missing argument",
}:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) optionalAttrs mkForce;

  utils = import ../../../utils.nix;
in
{
  _module.args =
    { }
    // optionalAttrs (type == "system") {
      myUtils = utils;
      pkgs = mkForce (import ../../../packages.nix { system = config.nixpkgs.hostPlatform; });
    }
    // optionalAttrs (type == "darwin") { pins = import ../../../pins pkgs; }
    // optionalAttrs (type == "darwin" || type == "home") { inherit utils; }
    // optionalAttrs (type == "darwin" || type == "system") {
      primaryUser = "biggs";
      inherit hostName;
    };
}
