type:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) optionalAttrs mkForce;
in
{
  _module.args = {
    myUtils = import ../../../my-utils.nix;
  }
  // optionalAttrs (type == "system") {
    pkgs = mkForce (import ../../../packages.nix { system = config.nixpkgs.hostPlatform; });
  }
  // optionalAttrs (type == "darwin") { pins = import ../../../pins pkgs; }
  // optionalAttrs (type == "darwin" || type == "system") { primaryUser = "biggs"; };
}
