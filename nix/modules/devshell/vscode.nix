{ pkgs, ... }: {
  devshell.packages = with pkgs; [
    # For extension "jnoortheen.nix-ide"
    nixd

    # For extension "ndonfris.fish-lsp"
    fish-lsp

    # For extension "maximsmol.vscode-lsp-generic"
    efm-langserver
    # efm-langserver launches commands with`sh`
    bash
    # These are used in the efm-langserver config
    coreutils
    jq
  ];
}
