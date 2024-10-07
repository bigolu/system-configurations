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
      inherit (import ./utilities.nix { inherit pkgs self; }) makeEnvironment makeCiEnvironment;

      lefthookEnvironment = makeEnvironment {
        packages = with pkgs; [
          lefthook
          # These are called in the lefthook configuration file, but aren't
          # specific to a task group e.g. format or check-lint
          gitMinimal
          parallel
        ];
      };

      lintingEnvironment = makeEnvironment {
        mergeWith = [
          # Runs the linters
          lefthookEnvironment
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

      formattingEnvironment = makeEnvironment {
        mergeWith = [
          # Runs the formatters
          lefthookEnvironment
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

      vsCodeEnvironment =
        let
          efmLsEnvironment = makeEnvironment {
            mergeWith = [ lintingEnvironment ];
            packages = [ pkgs.efm-langserver ];
          };

          luaLsEnvironment =
            let
              libraryMetaPackage = pkgs.runCommand "lua-ls-libraries" { } ''
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
                  symlink ${libraryMetaPackage} '.lua-ls-libraries'
                ''
              ];
            };

          nixdEnvironment = makeEnvironment {
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
            luaLsEnvironment
            efmLsEnvironment
            nixdEnvironment
          ];
          packages = with pkgs; [
            go
            taplo
          ];
        };

      taskRunnerEnvironment = makeEnvironment {
        packages = with pkgs; [
          just
          # For paging the output of `just list`
          less
        ];
      };

      versionControlEnvironment = makeEnvironment {
        mergeWith = [
          lefthookEnvironment
        ];
        packages = with pkgs; [
          gitMinimal
        ];
      };

      languageEnvironment = makeEnvironment {
        packages = with pkgs; [
          nix
          bashInteractive
          go
        ];
      };

      codeGenerationEnvironment = makeEnvironment {
        mergeWith = [
          # Runs the generators
          lefthookEnvironment
        ];
        # These get called in the lefthook config
        packages = with pkgs; [
          doctoc
          ripgrep
          coreutils
        ];
      };

      scriptEnvironment = makeEnvironment {
        packages = [ pkgs.script-dependencies ];
      };

      outputs = {
        # So we can cache them and pin a version.
        packages.nix-develop-gha = inputs'.nix-develop-gha.packages.default;
        devShells.gomod2nix = inputs'.gomod2nix.devShells.default;

        # So I can reference nixpkgs, with my overlays applied, from my scripts.
        legacyPackages.nixpkgs = pkgs;

        devShells = {
          default = makeEnvironment {
            name = "local";
            mergeWith = [
              vsCodeEnvironment
              lintingEnvironment
              formattingEnvironment
              codeGenerationEnvironment
              taskRunnerEnvironment
              versionControlEnvironment
              languageEnvironment
              scriptEnvironment
            ];
          };

          ci = makeCiEnvironment { name = "ci"; };

          ciLint = makeCiEnvironment {
            name = "ci-lint";
            mergeWith = [ lintingEnvironment ];
          };

          ciCheckStyle = makeCiEnvironment {
            name = "ci-check-style";
            mergeWith = [ formattingEnvironment ];
          };

          ciCodegen = makeCiEnvironment {
            name = "ci-codegen";
            mergeWith = [ codeGenerationEnvironment ];
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
