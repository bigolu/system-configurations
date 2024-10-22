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
      ...
    }:
    let
      inherit (lib.attrsets) optionalAttrs;
      makeShell = import ./make-shell { inherit pkgs self; };

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

      linting = makeShell {
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

          # These aren't linters, but they get called as part of certain linting
          # commands.
          gitMinimal
          parallel

          # TODO: If the YAML language server gets a CLI I should use that instead:
          # https://github.com/redhat-developer/yaml-language-server/issues/535
          yamllint

          # This reports the errors
          reviewdog

          # Runs the linters
          lefthook
        ];
      };

      formatting = makeShell {
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

          # Runs the formatters
          lefthook
        ];
      };

      vsCode =
        let
          efmLs = makeShell {
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
            makeShell {
              shellHook = ''
                symlink ${luaLibraries} '.lua-libraries'
              '';
            };

          nixd = makeShell {
            packages = [ pkgs.nixd ];
            # Why I need this:
            # https://github.com/nix-community/nixd/blob/c38702b17580a31e84c958b5feed3d8c7407f975/nixd/docs/configuration.md#default-configuration--who-needs-configuration
            shellHook = ''
              export NIX_PATH='nixpkgs='${lib.escapeShellArg inputs.nixpkgs}
            '';
          };
        in
        makeShell {
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

      taskRunner = makeShell {
        packages = with pkgs; [
          just

          # This gets called in the justfile
          coreutils

          # For paging the output of `just list`
          less
        ];
      };

      versionControl = makeShell {
        packages = with pkgs; [
          gitMinimal
          lefthook
        ];
      };

      languages = makeShell {
        packages = with pkgs; [
          bashInteractive
          go
        ];
      };

      codeGeneration = makeShell {
        packages = with pkgs; [
          # These get called in the lefthook config
          doctoc
          ripgrep
          coreutils
          gnused
          perl

          # Runs the generators
          lefthook
        ];
      };

      sync = makeShell {
        packages = with pkgs; [
          # These get called in the lefthook config
          gitMinimal
          just
          bash
          runAsAdmin
          # for uname
          coreutils

          # Runs the sync tasks
          lefthook
        ];
      };

      scriptDependencies = makeShell {
        packages = with pkgs; [ script-dependencies ];
      };

      smartPlug = makeShell {
        packages = [
          pythonWithPackages
        ];
      };

      outputs = {
        # So I can reference nixpkgs, with my overlays applied, from my scripts.
        legacyPackages.nixpkgs = pkgs;

        packages = {
          smartPlug = pkgs.writeShellApplication {
            name = "speakerctl";
            runtimeInputs = [ pythonWithPackages ];
            text = ''
              python ${../../dotfiles/smart_plug/smart_plug.py} "$@"
            '';
          };
        };

        devShells = {
          default = makeShell {
            mergeWith = [
              vsCode
              linting
              formatting
              codeGeneration
              sync
              taskRunner
              versionControl
              languages
              scriptDependencies
              smartPlug
            ];
          };

          # Have a general shell with common dependencies so I don't have
          # to make a shell for every CI workflow.
          ci = makeShell {
            packages = with pkgs; [
              # Why we need bashInteractive and not just bash:
              # https://discourse.nixos.org/t/what-is-bashinteractive/37379/2
              bashInteractive
              coreutils
            ];
          };

          ciLint = makeShell {
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

          ciCache = makeShell {
            packages = with pkgs; [
              nix-fast-build
            ];
          };

          ciRenovateTaskRunner = makeShell {
            packages = with pkgs; [
              gitMinimal
            ];
          };

          ciCheckForBrokenLinks = makeShell {
            packages = with pkgs; [
              gh
            ];
          };
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
