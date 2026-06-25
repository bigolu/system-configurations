{ pkgs, ... }:
{
  devshell.packages = with pkgs; [
    # TODO: Remove when this version reaches nixpkgs-unstable[1].
    #
    # [1]: https://github.com/NixOS/nixpkgs/pull/514847
    (lefthook.overrideAttrs rec {
      version = "2.1.9";
      vendorHash = "sha256-7+DzMPE2MqOfXR4G4INLggZhPD2dQmwfOFxBARrdYcI=";
      src = fetchFromGitHub {
        owner = "evilmartians";
        repo = "lefthook";
        rev = "v${version}";
        hash = "sha256-QANbvwD1q4UvdmMHdRUrNk1sNqq+hllUKJ1c1t53UD0=";
      };
    })
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
    sd
    shellcheck
    shfmt
    statix
    stylua
    taplo
  ];
}
