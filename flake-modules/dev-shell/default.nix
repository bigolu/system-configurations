{
  lib,
  inputs,
  self,
  ...
}:
{
  # For nixd:
  # https://github.com/nix-community/nixd/blob/c38702b17580a31e84c958b5feed3d8c7407f975/nixd/docs/configuration.md#options-options
  debug = true;

  perSystem =
    {
      system,
      pkgs,
      inputs',
      ...
    }:
    let
      inherit (lib.attrsets) optionalAttrs;
      inherit (import ./utilities.nix { inherit pkgs self; }) makeEnvironment;

      pythonWithPackages = pkgs.python3.withPackages (
        ps: with ps; [
          pip
          python-kasa
          diskcache
          ipython
          platformdirs
          psutil
          mypy
        ]
      );

      lefthook = makeEnvironment {
        packages = with pkgs; [
          pkgs.lefthook
          # These are called in the lefthook configuration file, but aren't
          # specific to a task group e.g. format or check-lint
          gitMinimal
          parallel
        ];
      };

      linting = makeEnvironment {
        mergeWith = [
          # Runs the linters
          lefthook
        ];

        packages = with pkgs; [
          actionlint
          deadnix
          fish
          lychee
          renovate # for renovate-config-validator
          shellcheck
          statix
          ltex-ls # for ltex-cli
          markdownlint-cli2
          desktop-file-utils
          golangci-lint
          config-file-validator
          taplo
          ruff
          go # for 'go mod tidy'
          typos
          dos2unix

          # These aren't linters, but they get called as part of a linting command
          gitMinimal

          # TODO: If the YAML language server gets a CLI I should use that instead:
          # https://github.com/redhat-developer/yaml-language-server/issues/535
          yamllint

          # This reports the errors
          reviewdog
        ];
      };

      formatting = makeEnvironment {
        mergeWith = [
          # Runs the formatters
          lefthook
        ];

        packages = with pkgs; [
          nixfmt-rfc-style
          nodePackages.prettier
          shfmt
          stylua
          just
          taplo
          ruff
          go # for gofmt
          fish # for fish_indent
        ];
      };

      vsCode =
        let
          efmLs = makeEnvironment {
            mergeWith = [ linting ];
            packages = [ pkgs.efm-langserver ];
          };

          luaLs =
            let
              luaLibraries = pkgs.runCommand "lua-libraries" { } ''
                mkdir "$out"
                cd "$out"
                ln -s ${pkgs.linkFarm "plugins" pkgs.myVimPlugins} ./plugins
                ln -s ${inputs.neodev-nvim}/types/nightly ./neodev
                ln -s ${pkgs.neovim}/share/nvim/runtime ./nvim-runtime
              '';
            in
            makeEnvironment {
              shellHooks = [
                ''
                  symlink ${luaLibraries} '.lua-libraries'
                ''
              ];
            };

          nixd = makeEnvironment {
            packages = [ pkgs.nixd ];
            # Why I need this:
            # https://github.com/nix-community/nixd/blob/c38702b17580a31e84c958b5feed3d8c7407f975/nixd/docs/configuration.md#default-configuration--who-needs-configuration
            shellHooks = [
              ''
                export NIX_PATH='nixpkgs='${lib.escapeShellArg inputs.nixpkgs}
              ''
            ];
          };
        in
        makeEnvironment {
          mergeWith = [
            luaLs
            efmLs
            nixd
          ];
          packages = with pkgs; [
            go
            taplo
          ];
        };

      taskRunner = makeEnvironment {
        packages = with pkgs; [
          just
          # For paging the output of `just list`
          less
        ];
      };

      versionControl = makeEnvironment {
        mergeWith = [
          lefthook
        ];
        packages = with pkgs; [
          gitMinimal
        ];
      };

      languages = makeEnvironment {
        packages = with pkgs; [
          nix
          bashInteractive
          go
        ];
      };

      codeGeneration = makeEnvironment {
        mergeWith = [
          # Runs the generators
          lefthook
        ];
        # These get called in the lefthook config
        packages = with pkgs; [
          doctoc
          ripgrep
          coreutils
        ];
      };

      scriptDependencies = makeEnvironment {
        packages = with pkgs; [ script-dependencies ];
      };

      smartPlug = makeEnvironment {
        packages = [
          pythonWithPackages
        ];
      };

      outputs = {
        # So we can cache them and pin a version.
        packages.nix-develop-gha = inputs'.nix-develop-gha.packages.default;
        devShells.gomod2nix = inputs'.gomod2nix.devShells.default;

        # So I can reference nixpkgs, with my overlays applied, from my scripts.
        legacyPackages.nixpkgs = pkgs;

        packages.smartPlug = pkgs.writeShellApplication {
          name = "speakerctl";
          runtimeInputs = [ pythonWithPackages ];
          text = ''
            python ${../../dotfiles/smart_plug/smart_plug.py} "$@"
          '';
        };

        devShells = {
          default = makeEnvironment {
            name = "local";
            mergeWith = [
              vsCode
              linting
              formatting
              codeGeneration
              taskRunner
              versionControl
              languages
              scriptDependencies
              smartPlug
            ];
          };

          # Have a general environment with common dependencies so I don't have
          # to make an environment for every CI workflow.
          ci = makeEnvironment {
            packages = with pkgs; [
              nix
              # Why we need bashInteractive and not just bash:
              # https://discourse.nixos.org/t/what-is-bashinteractive/37379/2
              bashInteractive
              coreutils
            ];
          };

          ciLint = makeEnvironment {
            mergeWith = [
              linting
            ];
            packages = with pkgs; [
              # Why we need bashInteractive and not just bash:
              # https://discourse.nixos.org/t/what-is-bashinteractive/37379/2
              bashInteractive
            ];
          };

          ciCheckStyle = formatting;

          ciCodegen = codeGeneration;
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
