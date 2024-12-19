# TODO: Maybe upstream all the community adapters, make it an optional addition
# to the build
# https://github.com/phiresky/ripgrep-all/discussions/199
{ pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
{
  home.packages = with pkgs; [
    # TODO: I should probably xdg-wrap the ripgrep in here too
    ripgrep-all
  ];

  repository.symlink = {
    home.file = {
      "${if isLinux then ".config" else "Library/Application Support"}/ripgrep-all/config.jsonc".source =
        "ripgrep/config.jsonc";
    };
  };
}
