{ pkgs, self }:
let
  inherit (pkgs) lib;

  makeMetaPackage =
    name: packages:
    pkgs.symlinkJoin {
      inherit name;
      paths = lib.lists.unique packages;
      # TODO: Nix should be able to link in prettier, I think it doesn't work
      # because the `prettier` is a symlink
      postBuild = lib.optionalString (builtins.elem pkgs.nodePackages.prettier packages) ''
        cd $out/bin
        ln -s ${pkgs.nodePackages.prettier}/bin/prettier ./prettier
      '';
    };

  makeDevShell =
    {
      packages ? [ ],
      shellHook ? "",
      name,
    }:
    let
      metaPackage = makeMetaPackage name packages;
    in
    # TODO: The devShells contain a lot of environment variables that are irrelevant
    # to our development environment, but Nix is working on a solution to
    # that: https://github.com/NixOS/nix/issues/7501
    pkgs.mkShellNoCC {
      inherit name;
      packages = [ metaPackage ];
      shellHook =
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
          function _bigolu_add_lines_to_nix_config {
            for line in "$@"; do
            NIX_CONFIG="''${NIX_CONFIG:-}"$'\n'"$line"$'\n'
            done
            export NIX_CONFIG
          }

          _bigolu_add_lines_to_nix_config \
          'flake-registry = '${pkgs.lib.escapeShellArg registry}

            # SYNC: OUR_CACHES
            # Caches we push to and pull from
            _bigolu_add_lines_to_nix_config \
            'extra-substituters = https://cache.garnix.io https://bigolu.cachix.org' \
            'extra-trusted-public-keys = cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g= bigolu.cachix.org-1:AJELdgYsv4CX7rJkuGu5HuVaOHcqlOgR07ZJfihVTIw='

            # Caches we only pull from
            _bigolu_add_lines_to_nix_config \
            'extra-substituters = https://nix-community.cachix.org' \
            'extra-trusted-public-keys = nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs='
        ''
        + shellHook;
    };

  makeCiDevShell =
    {
      packages ? [ ],
      shellHook ? "",
      name,
    }:
    let
      # To avoid having to make one line scripts lets put some common utils here
      ciCommon = with pkgs; [
        nix
        # Why we need bashInteractive and not just bash:
        # https://discourse.nixos.org/t/what-is-bashinteractive/37379/2
        bashInteractive
        coreutils
      ];
    in
    makeDevShell {
      packages = ciCommon ++ packages;
      inherit shellHook name;
    };
in
{
  inherit makeMetaPackage makeDevShell makeCiDevShell;
}
