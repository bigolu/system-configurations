{ pkgs }:
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
      scripts ? [ ],
      shellHook ? "",
      name ? "tools",
    }:
    let
      metaPackage = makeMetaPackage name (
        packages ++ (builtins.foldl' (acc: script: acc ++ script.dependencies) [ ] scripts)
      );
    in
    # TODO: The devShells contain a lot of environment variables that are irrelevant
    # to our development environment, but Nix is working on a solution to
    # that: https://github.com/NixOS/nix/issues/7501
    pkgs.mkShellNoCC {
      packages = [ metaPackage ];
      shellHook =
        ''
          function _bigolu_add_lines_to_nix_config {
            for line in "$@"; do
            NIX_CONFIG="''${NIX_CONFIG:-}"$'\n'"$line"$'\n'
            done
            export NIX_CONFIG
          }

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
      scripts ? [ ],
      shellHook ? "",
      name ? "tools",
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
      inherit shellHook scripts name;
    };
in
{
  inherit makeMetaPackage makeDevShell makeCiDevShell;
}
