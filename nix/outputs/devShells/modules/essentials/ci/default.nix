{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) optionals;
  inherit (pkgs.stdenv) isLinux;
in
{
  imports = optionals isLinux [ ./locale.nix ];

  devshell.packages = with pkgs; [
    # For the `run` steps in CI workflows/actions
    bash-script
    # For the save-cache action
    coreutils
    # For the setup action
    direnv-wrapper
  ];
}
