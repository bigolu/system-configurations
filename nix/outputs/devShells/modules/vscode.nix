{ pkgs, ... }:
let
  inherit (pkgs) coreutils;
in
{
  imports = [
    # For extension "llllvvuu.llllvvuu-glspc"
    {
      devshell.packages = with pkgs; [
        efm-langserver

        # These are used in the efm-langserver config
        coreutils
        # efm-langserver launches commands with`sh`
        dash
      ];
    }

    # For extension "rogalmic.bash-debug"
    {
      # It needs bash, cat, mkfifo, rm, and pkill
      devshell.packages = with pkgs; [
        bash
        coreutils
        partialPackages.pkill
      ];
    }
  ];

  devshell.packages = with pkgs; [
    # For extension "jnoortheen.nix-ide"
    nixd
    # For extension "ndonfris.fish-lsp"
    fish-lsp
    # For extension "golang.go"
    gopls
  ];
}
