{ pkgs, ... }:
{
  devshell.packages = with pkgs; [
    # For extension "jnoortheen.nix-ide"
    nixd

    # For extension "ndonfris.fish-lsp"
    fish-lsp

    # For extension "rogalmic.bash-debug".
    # It needs bash, cat, mkfifo, rm, and pkill
    bash
    coreutils
    partialPackages.pkill

    # For extension "maximsmol.vscode-lsp-generic"
    efm-langserver
    # These are used in the efm-langserver config
    coreutils
    jq
    # efm-langserver launches commands with`sh`
    dash
  ];
}
