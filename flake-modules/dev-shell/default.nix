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

      makeCiShell =
        spec:
        let
          ci-bash = pkgs.writeShellApplication {
            name = "ci-bash";
            text = ''
              exec ${pkgs.bashInteractive}/bin/bash \
                --noprofile \
                --norc \
                -o errexit \
                -o nounset \
                -o pipefail "$@"
            '';
          };
          specWithCiBash = spec // {
            packages = (spec.packages or [ ]) ++ [ ci-bash ];
          };
        in
        makeShell specWithCiBash;

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

          # Reports a diff in CI
          reviewdog
        ];
      };

      vsCode =
        let
          efmLs = makeShell {
            mergeWith = [ linting ];
            packages = [ pkgs.efm-langserver ];
          };

          luaLs = makeShell {
            shellHook = ''
              # SYNC: LUA_LIBRARY_PREFIX
              prefix='.lua-libraries'
              symlink ${pkgs.linkFarm "plugins" pkgs.myVimPlugins} "$prefix/plugins"
              symlink ${inputs.neodev-nvim}/types/nightly "$prefix/neodev"
              symlink ${pkgs.neovim}/share/nvim/runtime "$prefix/neovim-runtime"
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

          # Runs the generators
          lefthook

          # Reports a diff in CI
          reviewdog
        ];
      };

      sync = makeShell {
        packages = with pkgs; [
          # These get called in the lefthook config
          gitMinimal
          just
          bashInteractive
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
          ci = makeCiShell {
            packages = with pkgs; [ coreutils ];
          };

          ciLint = makeCiShell {
            mergeWith = [ linting ];
          };

          ciCheckStyle = makeCiShell {
            mergeWith = [ formatting ];
          };

          ciCodegen = makeCiShell {
            mergeWith = [ codeGeneration ];
          };

          ciCachePackages = makeCiShell {
            packages = with pkgs; [ nix-fast-build ];
          };

          ciRenovateTaskRunner = makeCiShell {
            packages = with pkgs; [ gitMinimal ];
          };

          ciCheckForBrokenLinks = makeCiShell {
            packages = with pkgs; [ gh ];
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
