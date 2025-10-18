{ pkgs, ... }:
{
  imports = [
    ../../cli.nix
    ./lua-language-server.nix
    # For `gofmt`, `go mod tidy`, and `go-tools`
    ../../../gozip.nix
    # For running mypy
    ../../../speakerctl.nix
  ];

  # TODO: Remove when using actionlint v1.7.8 or later
  devshell.startup.check.text = ''
    export LEFTHOOK_EXCLUDE="''${LEFTHOOK_EXCLUDE:+$LEFTHOOK_EXCLUDE,}actionlint"
  '';

  devshell.packages = with pkgs; [
    actionlint
    config-file-validator
    coreutils
    deadnix
    doctoc
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
    # I also use this for `isutf8` and `parallel`. `parallel` is used to run any
    # check that doesn't support multiple file arguments.
    moreutils
    nixfmt-rfc-style
    nixpkgs-lint-community
    nodePackages.prettier
    # for renovate-config-validator
    renovate
    ruff
    shellcheck
    shfmt
    statix
    stylua
    taplo
    typos
    nix-output-monitor
    bash
    jq
  ];
}
