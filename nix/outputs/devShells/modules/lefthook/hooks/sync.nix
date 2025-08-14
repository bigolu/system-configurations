{ pkgs, ... }:
{
  imports = [
    ../cli.nix
  ];

  devshell.packages = with pkgs; [
    # For `realpath`
    coreutils
    nix-output-monitor
    bash
  ];
}
