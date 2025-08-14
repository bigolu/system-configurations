{ pkgs, ... }:
{
  devshell.packages = with pkgs; [
    # flake-compat uses `builtins.fetchGit` which depends on git
    # https://github.com/NixOS/nix/issues/3533
    git
  ];
}
