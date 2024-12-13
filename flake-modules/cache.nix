# This output makes it easy to build all the packages that I want to cache in my
# cloud-hosted Nix package cache. I build this package from CI and cache everything
# that gets added to the Nix store as a result of building it.
_: {
  perSystem =
    {
      lib,
      pkgs,
      ...
    }:
    {
      legacyPackages.cache = lib.recurseIntoAttrs { inherit (pkgs) gomod2nix; };
    };
}
