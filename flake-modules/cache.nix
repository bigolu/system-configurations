_: {
  perSystem =
    {
      lib,
      pkgs,
      ...
    }:
    {
      # This output is used in CI by nix-fast-build to build everything that I want
      # cached. Once it's done building, I push the nix store to my cache.
      legacyPackages.cache = lib.recurseIntoAttrs { inherit (pkgs) gomod2nix; };
    };
}
