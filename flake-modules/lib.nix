{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.flake = flake-parts-lib.mkSubmoduleOptions {
    lib = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.unspecified;
      default = { };
      internal = true;
      description = "Utilities only to be used inside of this flake.";
    };
  };

  config.flake.lib = {
    # This applies `nixpkgs.lib.recursiveUpdate` to a list of sets, instead of just
    # two.
    recursiveMerge = sets: lib.lists.foldr lib.recursiveUpdate { } sets;

    # YYYYMMDDHHMMSS -> YYYY-MM-DD
    formatDate =
      date:
      let
        yearMonthDayStrings = builtins.match "(....)(..)(..).*" date;
      in
      lib.concatStringsSep "-" yearMonthDayStrings;

    systemNixSettings =
      { pkgs }:
      {
        allowed-users = [ "*" ];

        # https://github.com/NixOS/nix/issues/4442
        always-allow-substitutes = true;

        # Doesn't work on macOS
        auto-optimise-store = pkgs.stdenv.isLinux;

        build-users-group = "nixbld";

        builders = null;

        cores = 0;

        # Double the default size (64MiB -> 124MiB) since I kept hitting it
        download-buffer-size = 134217728;

        max-jobs = "auto";

        extra-sandbox-paths = [ ];

        require-sigs = true;

        # Doesn't work on macOS
        sandbox = pkgs.stdenv.isLinux;

        sandbox-fallback = false;

        trusted-users = [
          "root"
        ];

        trusted-substituters = [
          "https://cache.nixos.org"
          "https://nix-community.cachix.org"
          "https://bigolu.cachix.org"
        ];

        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="

          # SYNC: SYS_CONF_PUBLIC_KEYS
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "bigolu.cachix.org-1:AJELdgYsv4CX7rJkuGu5HuVaOHcqlOgR07ZJfihVTIw="
        ];

        experimental-features = [
          "nix-command"
          "flakes"
        ];

        # Don't cache tarballs. This way if I do something like
        # `nix run github:<repo>`, I will always get the up-to-date source
        tarball-ttl = 0;
      };
  };
}
