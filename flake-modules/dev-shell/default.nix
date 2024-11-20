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
      makeShell = import ./make-shell.nix {
        inherit pkgs;
        inherit (self.lib) root;
      };

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
          types-psutil
          mypy
        ]
      );

      plugctl = makeShell {
        packages = [
          pythonWithPackages
        ];
        shellHook = ''
          # Python without packages is also put on the PATH so I need to make sure
          # the one with packages comes first.
          PATH="${pythonWithPackages}/bin:$PATH"
        '';
      };

      linting = makeShell {
        mergeWith = [
          plugctl
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

          # These aren't linters, but they get called as part of certain linting
          # commands.
          gitMinimal
          parallel

          # TODO: If the YAML language server gets a CLI I should use that instead:
          # https://github.com/redhat-developer/yaml-language-server/issues/535
          yamllint

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
        in
        makeShell {
          mergeWith = [
            efmLs
          ];
          packages = with pkgs; [
            go
            taplo
            nixd
          ];
          shellHook = ''
            # Link python to a stable location so I don't have to update the python
            # path in VS Code when the nix store path for python changes.
            direnv_directory='.direnv'
            mkdir -p "$direnv_directory"
            ln --force --no-dereference --symbolic \
              ${pythonWithPackages} "$direnv_directory/python"

            # For lua-ls
            prefix='.lua-libraries'
            mkdir -p "$prefix"
            ln --force --no-dereference --symbolic \
              --target-directory "$prefix" \
              ${pkgs.linkFarm "plugins" pkgs.myVimPlugins} \
              ${inputs.neodev-nvim}/types/nightly \
              ${pkgs.neovim}/share/nvim/runtime
          '';
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
          nix-output-monitor

          # Runs the sync tasks
          lefthook
        ];
      };

      scriptDependencies = makeShell {
        packages = with pkgs; [
          script-dependencies
          cached-nix-shell
        ];
      };

      outputs = {
        legacyPackages =
          {
            # TODO: These are the outputs that I use from my flake inputs. Ideally, I'd
            # use `nix run/develop --inputs-from . <flake_input>#<output> ...`, but
            # when I do that, any of the 'follows' that I set on the flake input are
            # not used. I should see if this behavior is intended.
            gomod2nix = inputs'.gomod2nix.devShells.default;
            nixDevelopGha = inputs'.nix-develop-gha.packages.default;
            homeManager = inputs'.home-manager.packages.default;
          }
          // optionalAttrs pkgs.stdenv.isDarwin {
            nixDarwin = inputs'.nix-darwin.packages.default;
          };

        packages =
          let
            plugctl =
              let
                exeName = "plugctl";
              in
              pkgs.writeShellApplication {
                name = exeName;
                runtimeInputs = [ pythonWithPackages ];
                meta.mainProgram = exeName;
                text = ''
                  python ${../../dotfiles/smart_plug/smart_plug.py} "$@"
                '';
              };
          in
          {
            inherit plugctl;

            speakerctl =
              let
                exeName = "speakerctl";
              in
              pkgs.writeShellApplication {
                name = exeName;
                runtimeInputs = [ plugctl ];
                meta.mainProgram = exeName;
                text = ''
                  plugctl plug "$@"
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
              plugctl
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
