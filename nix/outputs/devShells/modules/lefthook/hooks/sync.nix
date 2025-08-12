{ pkgs, ... }:
{
  imports = [
    ../cli.nix
  ];

  packages = with pkgs; [
    # For `realpath`
    coreutils
    nix-output-monitor
    bash
  ];
}
