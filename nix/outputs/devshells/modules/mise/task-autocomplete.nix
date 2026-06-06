{ pkgs, ... }:
{
  devshell.packages = with pkgs; [
    fish
  ];
}
