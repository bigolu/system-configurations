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

    # For the lefthook sync hook and the git hooks that these programs create.
    git-auto-sync
    git-auto-check

    # For the check hook
    actionlint
    bash
    coreutils
    deadnix
    editorconfig-checker
    fish
    lua-language-server
    markdownlint-cli2
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
