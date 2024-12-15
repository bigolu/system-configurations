{
  utils,
  lib,
  ...
}:
{
  perSystem =
    {
      pkgs,
      ...
    }:
    let
      makeShell = import ./make-shell.nix {
        inherit pkgs;
        inherit (utils) projectRoot;
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

      plugctlPython = import ../../plugctl-python.nix pkgs;

      plugctl = makeShell {
        packages = [
          plugctlPython
        ];
        shellHook = ''
          # Python without packages is also put on the PATH so I need to make sure
          # the one with packages comes first.
          PATH="${plugctlPython}/bin:$PATH"
        '';
      };

      linting = makeShell {
        mergeWith = [
          # For mypy. Also for the python libraries used by plugctl so mypy can
          # factor in their types as well.
          plugctl
        ];

        packages = with pkgs; [
          actionlint
          deadnix
          fish
          lychee
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
          mergeWith = [
            linting
            formatting
            codeGeneration
          ];
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
}
