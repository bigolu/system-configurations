{
  _class,
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib) mkForce optionalAttrs;
  class = toString _class;
in
{
  _module.args = {
    # I'd prefer the name `utils`, but system-manager creates a module argument
    # with that name.
    myUtils = import ../../../utils.nix;
  }
  // optionalAttrs (class == "darwin" || class == "") { primaryUser = "biggs"; }
  // optionalAttrs (class == "") {
    pkgs = mkForce (import ../../../packages.nix { system = config.nixpkgs.hostPlatform; });
  }
  // optionalAttrs (class == "darwin") { pins = import ../../../pins pkgs; };
}
