{
  utils,
  lib,
  self,
  ...
}:
{
  perSystem =
    {
      pkgs,
      ...
    }:
    let
      inherit (utils) projectRoot;
      inherit (lib) fileset;

      makeShell =
        args@{
          inputsFrom ? [ ],
          ...
        }:
        let
          mkShellUnique = self.lib.mkShellUnique pkgs.mkShellNoCC;

          setPackagesPathHook =
            let
              relativePathStrings = [
                "flake.nix"
                "flake.lock"
                "default.nix"
                "nix"
              ];

              absolutePaths = map (path: projectRoot + "/${path}") relativePathStrings;

              packages = fileset.toSource {
                root = projectRoot;
                fileset = fileset.unions absolutePaths;
              };
            in
            ''
              # I reference packages.nix in several places so rather than hardcode
              # its path in all those places, I'll put its path in an environment
              # variable.
              #
              # You may be wondering why I'm using a fileset instead of just using
              # $PWD/nix/packages.nix. cached-nix-shell traces the files accessed
              # during the nix-shell invocation so it knows when to invalidate the
              # cache. When I use $PWD, a lot of files unrelated to nix, like
              # $PWD/.git/index, become part of the trace, resulting in much more
              # cache invalidations.
              export PACKAGES=${packages}/nix/packages.nix
            '';

          essentials = mkShellUnique {
            packages = with pkgs; [ cached-nix-shell ];
            shellHook = setPackagesPathHook;
          };
        in
        mkShellUnique (args // { inputsFrom = inputsFrom ++ [ essentials ]; });

      makeCiShell =
        args@{
          packages ? [ ],
          ...
        }:
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
        in
        makeShell (args // { packages = packages ++ [ ci-bash ]; });

      plugctlPython = import ../plugctl-python.nix pkgs;

      plugctl = makeShell {
        packages = [
          plugctlPython
        ];
        shellHook = ''
          # Regular python, i.e. the one without plugctl's packages, is also put on
          # the PATH so I need to make sure the one for plugctl comes first.
          PATH="${plugctlPython}/bin:$PATH"
        '';
      };

      linting = makeShell {
        inputsFrom = [
          # For mypy. Also for the python libraries used by plugctl so mypy can
          # factor in their types as well.
          plugctl
        ];

        packages = with pkgs; [
          actionlint
          deadnix
          fish
          # for renovate-config-validator
          renovate
          shellcheck
          statix
          # for ltex-cli
          ltex-ls
          markdownlint-cli2
          desktop-file-utils
          golangci-lint
          config-file-validator
          taplo
          ruff
          # for 'go mod tidy'
          go
          typos
          dos2unix
          partialPackages.isutf8
          # TODO: If the YAML language server gets a CLI I should use that instead:
          # https://github.com/redhat-developer/yaml-language-server/issues/535
          yamllint

          # These aren't linters, but they get called as part of certain linting
          # commands.
          gitMinimal
          parallel

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
          # The set passed to linkFarm can only contain derivations
          plugins = pkgs.linkFarm "plugins" (utils.removeRecurseIntoAttrs pkgs.myVimPlugins);

          efmLs = makeShell {
            inputsFrom = [ linting ];
            packages = [ pkgs.efm-langserver ];
          };
        in
        makeShell {
          inputsFrom = [
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
              ${plugctlPython} "$direnv_directory/python"

            # For lua-ls
            prefix='.lua-libraries'
            mkdir -p "$prefix"
            ln --force --no-dereference --symbolic \
              ${plugins} "$prefix/neovim-plugins"
            ln --force --no-dereference --symbolic \
              ${pkgs.neovim}/share/nvim/runtime "$prefix/neovim-runtime"
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
        ];
      };

      local = makeShell {
        inputsFrom = [
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
    in
    {
      devShells = {
        inherit local;
        default = local;

        # Have a general shell with common dependencies so I don't have
        # to make a shell for every CI workflow.
        ci = makeCiShell {
          packages = with pkgs; [ coreutils ];
        };

        ciCheckPullRequest = makeCiShell {
          inputsFrom = [
            linting
            formatting
            codeGeneration
          ];
        };

        ciCachePackages = makeCiShell {
          packages = with pkgs; [ nix-fast-build ];
        };

        ciRenovate = makeCiShell {
          packages = with pkgs; [ renovate ];
          shellHook = ''
            export RENOVATE_CONFIG_FILE="$PWD/.github/renovate-global.json5"
            export LOG_LEVEL='debug'
          '';
        };

        ciCheckForBrokenLinks = makeCiShell {
          packages = with pkgs; [ gh ];
        };
      };
    };
}
