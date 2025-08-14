{ pkgs, ... }:
{
  imports = [
    ../cli.nix
  ];

  devshell.packages = with pkgs; [
    typos
  ];
}
