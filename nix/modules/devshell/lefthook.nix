{ pkgs, ... }:
{
  devshell.packages = with pkgs; [
    lefthook
    # TODO: Lefthook won't run unless git is present so maybe nixpkgs should make it
    # a dependency.
    git

    # For the post-* hooks
    git-auto-sync

    # For the check hook
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
