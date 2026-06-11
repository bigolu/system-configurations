{ pkgs, ... }:
{
  devshell.packages = with pkgs; [
    # For extension "jnoortheen.nix-ide"
    nixd

    # For extension "ndonfris.fish-lsp"
    fish-lsp

    # For extension "rogalmic.bash-debug".
    bash
    (filterPrograms coreutils [
      # It's a multi-call binary so all programs besides this one are symlinks
      # to it.
      "coreutils"
      "cat"
      "mkfifo"
      "rm"
    ])
    (filterPrograms procps [ "pkill" ])

    # For extension "maximsmol.vscode-lsp-generic"
    efm-langserver
    # efm-langserver launches commands with`sh`
    dash
    # These are used in the efm-langserver config
    coreutils
    jq
  ];
}
