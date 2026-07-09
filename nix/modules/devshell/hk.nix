{ pkgs, ... }: {
  devshell.packages = with pkgs; [
    hk
    # So I can run `pkl eval hk.pkl` which will fetch any imports so pkl-lsp can
    # reference them.
    pkl
    # TODO: This is required for hk's shell completion so nixpkgs should make it
    # a dependency.
    usage

    # For the sync hook and the git hooks that these programs create.
    git-auto-sync
    git-auto-check

    # For the check hook
    actionlint
    coreutils
    deadnix
    editorconfig-checker
    fish
    lua-language-server
    markdownlint-cli2
    nixfmt
    nixpkgs-lint-community
    pkl
    prettier
    # for renovate-config-validator
    renovate
    shellcheck
    shfmt
    statix
    stylua
    taplo
  ];
}
