{ pkgs, ... }:
{
  imports = [
    ../cli.nix
  ];

  devshell.packages = with pkgs; [
    git-auto-sync
  ];
}
