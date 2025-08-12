{
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../flake-compat.nix
    ../mise/cli.nix
  ]
  ++ lib.optionals pkgs.stdenv.isLinux [
    ./locale.nix
  ];

  packages = with pkgs; [
    # For the `run` steps in CI workflows/actions
    bash-script
    # For the save-cache action
    coreutils
    # For the setup action
    direnv-wrapper
  ];
}
