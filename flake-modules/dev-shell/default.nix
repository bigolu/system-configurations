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
      inherit (import ./utilities.nix { inherit pkgs self; })
        mergeDependencies
        makeDevShell
        makeCiDevShell
        ;

      lefthookDependencies = {
        packages = with pkgs; [
          lefthook

          # These are called in the lefthook configuration file, but aren't
          # specific to a task group e.g. format or check-lint
          gitMinimal
          parallel
        ];
      };

      lintingDependencies = mergeDependencies [
        # Runs the linters
        lefthookDependencies

        {
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
        }
      ];

      formattingDependencies = mergeDependencies [
        # Runs the formatters
        lefthookDependencies

        {
          packages = with pkgs; [
            nixfmt-rfc-style
            nodePackages.prettier
            shfmt
            stylua
            just
            taplo
            ruff
            # for gofmt
            go
            # for fish_indent
            fish
          ];
        }
      ];

      vsCodeDependencies =
        let
          efmLsDependencies = mergeDependencies [
            lintingDependencies
            { packages = [ pkgs.efm-langserver ]; }
          ];

          luaLsDependencies =
            let
              libraryMetaPackage = pkgs.runCommand "lua-ls-libraries" { } ''
                mkdir "$out"
                cd "$out"
                ln -s ${pkgs.linkFarm "plugins" pkgs.myVimPlugins} ./plugins
                ln -s ${inputs.neodev-nvim}/types/nightly ./neodev
                ln -s ${pkgs.neovim}/share/nvim/runtime ./nvim-runtime
              '';
            in
            {
              shellHooks = [
                ''
                  symlink ${libraryMetaPackage} '.lua-ls-libraries'
                ''
              ];
            };

          nixdDependencies = {
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
        mergeDependencies [
          luaLsDependencies
          efmLsDependencies
          nixdDependencies
          {
            packages = with pkgs; [
              go
              taplo
            ];
          }
        ];

      taskRunnerDependencies = {
        packages = with pkgs; [
          just
          # For paging the output of `just list`
          less
        ];
      };

      versionControlDependencies = mergeDependencies [
        lefthookDependencies
        {
          packages = with pkgs; [
            gitMinimal
          ];
        }
      ];

      languageDependencies = {
        packages = with pkgs; [
          nix
          bashInteractive
          go
        ];
      };

      codeGenerationDependencies = mergeDependencies [
        # Runs the generators
        lefthookDependencies

        {
          # These gets called in the lefthook config
          packages = with pkgs; [
            doctoc
            ripgrep
            coreutils
          ];
        }
      ];

      scriptDependencies = {
        packages = [ pkgs.script-dependencies ];
      };

      outputs = {
        # So we can cache them and pin a version.
        packages.nix-develop-gha = inputs'.nix-develop-gha.packages.default;
        devShells.gomod2nix = inputs'.gomod2nix.devShells.default;

        # So I can reference nixpkgs, with my overlays applied, from my scripts.
        legacyPackages.nixpkgs = pkgs;

        devShells = {
          default = makeDevShell {
            name = "local";
            dependencies = mergeDependencies [
              vsCodeDependencies
              lintingDependencies
              formattingDependencies
              codeGenerationDependencies
              taskRunnerDependencies
              versionControlDependencies
              languageDependencies
              scriptDependencies
            ];
          };

          ci = makeCiDevShell { name = "ci"; };

          ciLint = makeCiDevShell {
            name = "ci-lint";
            dependencies = lintingDependencies;
          };

          ciCheckStyle = makeCiDevShell {
            name = "ci-check-style";
            dependencies = formattingDependencies;
          };

          ciCodegen = makeCiDevShell {
            name = "ci-codegen";
            dependencies = codeGenerationDependencies;
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
