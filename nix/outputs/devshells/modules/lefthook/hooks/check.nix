{ pkgs, ... }:
{
  imports = [
    ../cli.nix
  ];

  devshell.packages = with pkgs; [
    actionlint
    bash
    coreutils
    deadnix
    editorconfig-checker
    fish
    lua-language-server
    markdown2html-converter
    markdownlint-cli2
    # I use `parallel` to run any check that doesn't support multiple file arguments.
    moreutils
    nix-fast-build
    nixfmt
    nixpkgs-lint-community
    prettier
    # for renovate-config-validator
    renovate
    shellcheck
    shfmt
    statix
    stylua
    taplo
    typos
  ];
}
