{
  utils,
  lib,
  ...
}:
{
  perSystem =
    {
      pkgs,
      self',
      ...
    }:
    let
      inherit (utils) projectRoot removeRecurseIntoAttrs;
      inherit (lib)
        fileset
        pipe
        init
        splitString
        optionalAttrs
        ;
      inherit (builtins) readFile;
      inherit (pkgs)
        mkShellNoCC
        mkShellUniqueWrapper
        linkFarm
        runCommand
        ;
      inherit (pkgs.stdenv) isLinux;

      makeShell =
        args@{
          inputsFrom ? [ ],
          ...
        }:
        let
          mkShellUniqueNoCC = mkShellUniqueWrapper mkShellNoCC;

          flakePackageSetHook =
            let
              filesReferencedByFlakePackageSetFile =
                pipe
                  [
                    "flake.nix"
                    "flake.lock"
                    "default.nix"
                    "nix"
                  ]
                  [
                    (map (relativePath: projectRoot + "/${relativePath}"))
                    fileset.unions
                    (
                      union:
                      fileset.toSource {
                        root = projectRoot;
                        fileset = union;
                      }
                    )
                  ];
            in
            ''
              # To avoid hard coding the path to the flake package set in every
              # script with a nix-shell shebang, I export a variable with the path.
              #
              # You may be wondering why I'm using a fileset instead of just using
              # $PWD/nix/flake-package-set.nix. cached-nix-shell traces the files
              # accessed during the nix-shell invocation so it knows when to
              # invalidate the cache. When I use $PWD, a lot more files, like
              # $PWD/.git/index, become part of the trace, resulting in much more
              # cache invalidations.
              export FLAKE_PACKAGE_SET_FILE=${filesReferencedByFlakePackageSetFile}/nix/flake-package-set.nix
            '';

          essentials = mkShellUniqueNoCC {
            packages = with pkgs; [ cached-nix-shell ];
            shellHook = flakePackageSetHook;
          };
        in
        mkShellUniqueNoCC (args // { inputsFrom = inputsFrom ++ [ essentials ]; });

      makeCiShell =
        args@{
          inputsFrom ? [ ],
          ...
        }:
        let
          # Nix recommends setting this for non-NixOS Linux distributions[1] and
          # Ubuntu is used in CI.
          #
          # TODO: See if Nix should do this as part of its setup script
          #
          # [1]: https://nixos.wiki/wiki/Locales
          localeArchiveHook = ''
            export LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive
          '';

          ciEssentials = makeShell (
            {
              packages = with pkgs; [ ci-bash ];
            }
            // optionalAttrs isLinux {
              shellHook = localeArchiveHook;
            }
          );
        in
        makeShell (args // { inputsFrom = inputsFrom ++ [ ciEssentials ]; });

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
          # These get called in the lefthook config
          actionlint
          deadnix
          fish
          # for renovate-config-validator
          renovate
          shellcheck
          statix
          # for ltex-cli-plus
          ltex-ls-plus
          markdownlint-cli2
          desktop-file-utils
          golangci-lint
          config-file-validator
          taplo
          ruff
          # for 'go mod tidy'
          go
          typos
          # TODO: If the YAML language server gets a CLI I should use that instead:
          # https://github.com/redhat-developer/yaml-language-server/issues/535
          yamllint
          editorconfig-checker
          nixpkgs-lint-community
          hjson-go
          # For isutf8 and parallel. parallel isn't a linter, but it's used to run
          # any linter that doesn't support multiple file arguments.
          moreutils

          # These aren't linters, but they also get called in lefthook as part of
          # certain linting commands.
          gitMinimal

          # Runs the linters
          lefthook
        ];

        shellHook =
          let
            direnvStdlib = runCommand "direnv-stdlib.bash" {
              nativeBuildInputs = [ pkgs.direnv ];
            } "direnv stdlib > $out";
          in
          ''
            direnv_directory='.direnv'
            mkdir -p "$direnv_directory"
            ln --force --no-dereference --symbolic \
              ${direnvStdlib} "$direnv_directory/stdlib.bash"
          '';
      };

      formatting = makeShell {
        packages = with pkgs; [
          # These get called in the lefthook config
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
          plugins = linkFarm "plugins" (removeRecurseIntoAttrs pkgs.myVimPlugins);

          efmLs = makeShell {
            inputsFrom = [ linting ];
            packages = with pkgs; [
              efm-langserver
              # I use this to transform the output of some linters into something efm
              # can more easily parse.
              jq
            ];
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
            prefix='lua-libraries'
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
          gomod2nix

          # Runs the generators
          lefthook
        ];
      };

      sync = makeShell {
        packages = with pkgs; [
          # These get called in the lefthook config
          gitMinimal
          runAsAdmin

          # Runs the sync tasks
          lefthook
        ];
      };

      scriptDependencies =
        let
          dependencyFile =
            runCommand "script-dependencies"
              {
                nativeBuildInputs = with pkgs; [
                  ripgrep
                ];
              }
              ''
                # Extract script dependencies from their nix-shell shebangs.
                #
                # The shebang looks something like:
                #   #! nix-shell --packages "with ...; [dep1 dep2 dep3]"
                #
                # So this command will extract everything between the brackets i.e.
                #   'dep1 dep2 dep3'.
                #
                # Each line printed will contain the extraction above, per script.
                rg \
                  --no-filename \
                  --glob '*.bash' \
                  '^#! nix-shell (--packages|-p) .*\[(?P<packages>.*)\].*' \
                  --replace '$packages' \
                  ${projectRoot + /scripts} |

                # Flatten the output of the previous command i.e. print _one_
                # dependency per line
                rg --only-matching '[^\s]+' |

                sort --unique > $out
              '';
        in
        pipe dependencyFile [
          readFile
          (splitString "\n")
          # The file ends in a newline so the last line will be empty
          init
          (map (dependencyName: pkgs.${dependencyName}))
          (dependencies: makeShell { packages = dependencies; })
        ];
    in
    {
      devShells = {
        default = self'.devShells.local;

        local = makeShell {
          name = "local";
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

        ci-default = makeCiShell {
          name = "ci-default";
        };

        ci-check-pull-request = makeCiShell {
          name = "ci-check-pull-request";
          inputsFrom = [
            linting
            formatting
            codeGeneration
          ];
        };

        ci-renovate = makeCiShell {
          name = "ci-renovate";
          packages = with pkgs; [ renovate ];
          shellHook = ''
            export RENOVATE_CONFIG_FILE="$PWD/.github/renovate-global.json5"
            export LOG_LEVEL='debug'
            # Post-Upgrade tasks are executed in the directory of the repo that's
            # currently being processed so I'm going to save the path to this repo.
            export RENOVATE_BOT_REPO="$PWD"
          '';
        };
      };
    };
}
