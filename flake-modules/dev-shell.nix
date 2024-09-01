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

        # Formatters
        treefmt
        black
        usort
        nodePackages.prettier
        shfmt
        alejandra
        stylua
        fish # for fish_indent

        # Linters
        deadnix
        statix
        renovate # for renovate-config-validator
        actionlint

        # Version control
        git
        lefthook

        # Language servers
        nil
        taplo
        efm-langserver

        # Bash script dependencies
        coreutils-full
        moreutils
        findutils
        jq
        which
        gnused
        gnugrep
        fd
        ripgrep
        yq-go

        # Miscellaneous
        just
        doctoc
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
