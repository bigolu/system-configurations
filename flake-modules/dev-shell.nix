{
  lib,
  inputs,
  ...
}: {
  perSystem = {
    system,
    pkgs,
    inputs',
    ...
  }: let
    inherit (lib.attrsets) optionalAttrs;

    # Make a meta-package so we don't have a $PATH entry for each package
    metaPackage = pkgs.symlinkJoin {
      name = "tools";
      paths = with pkgs; [
        # Languages
        bashInteractive
        go
        nix

        # Fixers and linters
        actionlint
        alejandra
        black
        deadnix
        fish # for fish_indent
        lychee
        nodePackages.prettier
        renovate # for renovate-config-validator
        shellcheck
        shfmt
        statix
        stylua
        treefmt
        usort
        # TODO: If the YAML language server gets a CLI I should use that instead:
        # https://github.com/redhat-developer/yaml-language-server/issues/535
        yamllint

        # Version control
        git
        lefthook

        # Language servers
        efm-langserver
        nil
        taplo

        # Bash script dependencies
        coreutils-full
        fd
        findutils
        gnugrep
        gnused
        jq
        moreutils
        ripgrep
        which
        yq-go
        ast-grep

        # Miscellaneous
        doctoc
        just
        reviewdog

        # For paging the output of `just list`
        less
      ];

      # TODO: Nix should be able to link in prettier, I think it doesn't work
      # because the `prettier` is a symlink
      postBuild = ''
        cd $out/bin
        ln -s ${pkgs.nodePackages.prettier}/bin/prettier ./prettier
      '';
    };

    outputs = {
      # TODO: The devShell contains a lot of environment variables that are irrelevant
      # to our development environment, but Nix is working on a solution to
      # that: https://github.com/NixOS/nix/issues/7501
      devShells.default = pkgs.mkShellNoCC {
        packages = [
          metaPackage
        ];
      };

      devShells.gomod2nix = inputs'.gomod2nix.devShells.default;
    };

    supportedSystems = with inputs.flake-utils.lib.system; [x86_64-linux x86_64-darwin];
    isSupportedSystem = builtins.elem system supportedSystems;
  in
    optionalAttrs isSupportedSystem outputs;
}
