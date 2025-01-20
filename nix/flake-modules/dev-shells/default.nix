moduleContext@{
  utils,
  lib,
  ...
}:
{
  perSystem =
    perSystemContext@{
      pkgs,
      self',
      ...
    }:
    let
      inherit (builtins) attrValues;
      inherit (utils) projectRoot;
      inherit (lib)
        fileset
        pipe
        optionalAttrs
        ;
      inherit (pkgs.stdenv) isLinux;

      partials = import ./partials.nix (moduleContext // perSystemContext);

      makeShell =
        args@{
          inputsFrom ? [ ],
          ...
        }:
        let
          inherit (pkgs) mkShellUniqueNoCC;

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
            # cached-nix-shell is used in script shebangs
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
    in
    {
      devShells = {
        default = self'.devShells.local;

        local = makeShell {
          name = "local";
          inputsFrom = attrValues partials;
        };

        ci-essentials = makeCiShell {
          name = "ci-essentials";
        };

        ci-check-pull-request = makeCiShell {
          name = "ci-check-pull-request";
          inputsFrom = with partials; [
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
            # currently being processed. I'm going to save the path to this repo so I
            # can run the scripts in it.
            export RENOVATE_BOT_REPO="$PWD"
          '';
        };
      };
    };
}
