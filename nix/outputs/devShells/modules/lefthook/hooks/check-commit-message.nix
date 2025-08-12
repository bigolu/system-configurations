{ pkgs, ... }:
{
  imports = [
    ../cli.nix
  ];

  packages = with pkgs; [
    typos
  ];
}
