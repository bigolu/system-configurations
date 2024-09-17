{
  lib,
  inputs,
  ...
}:
{
  perSystem =
    {
      system,
      pkgs,
      inputs',
      ...
    }:
    let
      inherit (lib.attrsets) optionalAttrs;

      makeMetaPackage =
        packages:
        pkgs.symlinkJoin {
          name = "tools";
          paths = lib.lists.unique packages;
          # TODO: Nix should be able to link in prettier, I think it doesn't work
          # because the `prettier` is a symlink
          postBuild = lib.optionalString (builtins.elem pkgs.nodePackages.prettier packages) ''
            cd $out/bin
            ln -s ${pkgs.nodePackages.prettier}/bin/prettier ./prettier
          '';
        };

      makeDevShell =
        {
          packages ? [ ],
          shellHook ? "",
        }:
        let
          metaPackage = makeMetaPackage packages;
        in
        # TODO: The devShells contain a lot of environment variables that are irrelevant
        # to our development environment, but Nix is working on a solution to
        # that: https://github.com/NixOS/nix/issues/7501
        pkgs.mkShellNoCC {
          packages = [ metaPackage ];
          shellHook =
            ''
              function _bigolu_add_lines_to_nix_config {
                for line in "$@"; do
                  NIX_CONFIG="''${NIX_CONFIG:-}"$'\n'"$line"
                done
                export NIX_CONFIG
              }

              # SYNC: OUR_CACHES
              # Caches we push to and pull from
              _bigolu_add_lines_to_nix_config \
                'extra-substituters = https://cache.garnix.io https://bigolu.cachix.org' \
                'extra-trusted-public-keys = cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g= bigolu.cachix.org-1:AJELdgYsv4CX7rJkuGu5HuVaOHcqlOgR07ZJfihVTIw='

              # Caches we only pull from
              _bigolu_add_lines_to_nix_config \
                'extra-substituters = https://nix-community.cachix.org' \
                'extra-trusted-public-keys = nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs='
            ''
            + shellHook;
        };

      makeCiDevShell =
        {
          packages ? [ ],
          shellHook ? "",
        }:
        let
          # To avoid having to make one line scripts lets put some common utils here
          ciCommon = with pkgs; [
            nix
            # Why we need bashInteractive and not just bash:
            # https://discourse.nixos.org/t/what-is-bashinteractive/37379/2
            bashInteractive
            coreutils
          ];
        in
        makeDevShell {
          packages = ciCommon ++ packages;
          inherit shellHook;
        };

      lintersAndFixers = with pkgs; [
        actionlint
        nixfmt-rfc-style
        deadnix
        fish # for fish_indent, also used as logic linter
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
        ltex-ls # for ltex-cli
        markdownlint-cli2
        desktop-file-utils
        golangci-lint
        config-file-validator
        taplo
        ruff
        reviewdog
        just
        go
        dotenv-linter
      ];

      scripts = import ./scripts.nix {
        inherit pkgs lintersAndFixers;
        inherit (inputs) self;
      };

      vsCodeDependencies = with pkgs; [
        go
        efm-langserver
        nixd
      ];

      linkLuaLsLibrariesHook =
        let
          luaLsLibraries = import ./lua-libraries.nix { inherit pkgs inputs; };
        in
        ''
          dest='.lua-ls-libraries'
          if [ -L "$dest" ]; then
            ${pkgs.coreutils}/bin/rm "$dest"
          fi
          ${pkgs.coreutils}/bin/ln --symbolic ${lib.escapeShellArg luaLsLibraries} "$dest"
        '';

      outputs = {
        devShells = {
          default = makeDevShell {
            packages =
              vsCodeDependencies
              ++ lintersAndFixers
              ++ scripts.allDependencies
              ++ (with pkgs; [
                # Languages
                nix
                bashInteractive
                go

                # Version control
                gitMinimal
                lefthook

                # Task runner
                just
                less # For paging the output of `just list`
              ]);
            shellHook =
              ''
                # For nixd
                export NIX_PATH=${lib.escapeShellArg inputs.nixpkgs}

                # Even though I never use the scripts made by resholve, I still
                # want resholve to make them so it can verify that I specified
                # their dependencies properly. To force the package containing
                # the resholve scripts to be evaluated, I'm adding a reference
                # to the package here.
                # ${lib.escapeShellArg scripts.meta}
              ''
              + linkLuaLsLibrariesHook;
          };

          ci = makeCiDevShell { };

          ciLint = makeCiDevShell {
            packages = scripts.dependenciesByName.ci-lint.inputs ++ scripts.dependenciesByName.lint.inputs;
            shellHook = linkLuaLsLibrariesHook;
          };

          ciCodegen = makeCiDevShell {
            packages = scripts.dependenciesByName.ci-code-generation.inputs;
          };

          ciRenovate = makeCiDevShell {
            packages =
              scripts.dependenciesByName.ci-set-nix-direnv-hash.inputs
              ++ scripts.dependenciesByName.generate-gomod2nix-lock.inputs;
          };

          ciAutoMerge = makeCiDevShell {
            packages = scripts.dependenciesByName.ci-auto-merge.inputs;
          };

          ciTest = makeCiDevShell {
            packages = scripts.dependenciesByName.test.inputs;
          };

          gomod2nix = inputs'.gomod2nix.devShells.default;
        };
      };

      supportedSystems = with inputs.flake-utils.lib.system; [
        x86_64-linux
        x86_64-darwin
      ];
      isSupportedSystem = builtins.elem system supportedSystems;
    in
    optionalAttrs isSupportedSystem outputs;
}
