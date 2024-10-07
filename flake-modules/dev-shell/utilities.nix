{ pkgs, self }:
let
  inherit (pkgs) lib;

  makeMetaPackage =
    { name, packages }:
    pkgs.symlinkJoin {
      inherit name;
      paths = packages;
      # TODO: symlinkJoin doesn't work if the file to link is a symlink itself.
      # More info: https://ertt.ca/blog/2022/01-12-nix-symlinkJoin-nodePackages/
      postBuild = ''
        shopt -s nullglob
        for file in $out/lib/node_modules/.bin/*; do
          ln --symbolic \
            "$(readlink --canonicalize-missing "$file")" \
            "$out/bin/$(basename $file)"
        done
      '';
    };

  makeEnvironment =
    {
      name ? "tools",
      packages ? [ ],
      shellHooks ? [ ],
      mergeWith ? [ ],
    }:
    let
      helperFunctionsHook = ''
        function add_lines_to_nix_config {
          for line in "$@"; do
          NIX_CONFIG="''${NIX_CONFIG:-}"$'\n'"$line"$'\n'
          done
          export NIX_CONFIG
        }

        function symlink {
          source="$1"
          destination="$2"

          if [ -L "$destination" ]; then
            ${pkgs.coreutils}/bin/rm "$destination"
          fi
          ${pkgs.coreutils}/bin/ln --symbolic "$source" "$destination"
        }
      '';

      cacheHook = ''
        # SYNC: OUR_CACHES
        # Caches we push to and pull from
        add_lines_to_nix_config \
          'extra-substituters = https://cache.garnix.io https://bigolu.cachix.org' \
          'extra-trusted-public-keys = cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g= bigolu.cachix.org-1:AJELdgYsv4CX7rJkuGu5HuVaOHcqlOgR07ZJfihVTIw='

        # Caches we only pull from
        add_lines_to_nix_config \
          'extra-substituters = https://nix-community.cachix.org' \
          'extra-trusted-public-keys = nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs='
      '';

      registryHook =
        let
          # Adapted from home-manager:
          # https://github.com/nix-community/home-manager/blob/2f23fa308a7c067e52dfcc30a0758f47043ec176/modules/misc/nix.nix#L215
          registry = (pkgs.formats.json { }).generate "registry.json" {
            version = 2;
            flakes = [
              {
                exact = true;
                from = {
                  id = "local";
                  type = "indirect";
                };
                to = {
                  type = "path";
                  path = self.outPath;
                  inherit (self) lastModified narHash;
                };
              }
            ];
          };
        in
        ''
          add_lines_to_nix_config \
            'flake-registry = '${pkgs.lib.escapeShellArg registry}
        '';

      mergedPackages = lib.trivial.pipe mergeWith [
        (map (env: env._packages))
        (packageLists: packageLists ++ [ packages ])
        lib.lists.concatLists
        lib.lists.unique
      ];
      mergedShellHooks = lib.trivial.pipe mergeWith [
        (map (env: env._shellHooks))
        (
          shellHookLists:
          [
            [
              helperFunctionsHook
              registryHook
              cacheHook
            ]
          ]
          ++ shellHookLists
          ++ [ shellHooks ]
        )
        lib.lists.concatLists
        lib.lists.unique
      ];
      shell = pkgs.mkShellNoCC {
        inherit name;
        packages = [
          (makeMetaPackage {
            inherit name;
            packages = mergedPackages;
          })
        ];
        shellHook = lib.strings.concatStringsSep "\n" mergedShellHooks;
      };
      modifiedShell = shell // {
        _packages = mergedPackages;
        _shellHooks = mergedShellHooks;
      };
    in
    modifiedShell;
in
{
  inherit makeEnvironment;
}
