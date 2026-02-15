{ pkgs, ... }:
{
  imports = [
    ../../cli.nix
    ./lua-language-server.nix
    # For `gofmt`, `go mod tidy`, and `go-tools`
    ../../../gozip.nix
  ];

  devshell.packages = with pkgs; [
    actionlint
    bash
    config-file-validator
    coreutils
    deadnix
    editorconfig-checker
    fish
    go-tools
    gomod2nix
    markdown2html-converter
    markdownlint-cli2
    # TODO: I use `chronic` to hide the output of commands that produce a lot of
    # output even when they exit successfully. I should see if I could change
    # this upstream.
    #
    # I also use `parallel` to run any check that doesn't support multiple file
    # arguments.
    moreutils
    nix-output-monitor
    nixfmt
    nixpkgs-lint-community
    nodePackages.prettier
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
