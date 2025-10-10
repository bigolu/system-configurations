{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) optional;
  inherit (pkgs.stdenv) isLinux;
in
{
  imports = optional isLinux ./locale.nix;

  devshell.packages = with pkgs; [
    # For the `run` steps in CI workflows/actions
    bash-script
    # For the save-cache action
    coreutils
  ];
}
