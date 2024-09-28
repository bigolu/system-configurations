{
  lib,
  flake-parts-lib,
  ...
}:
{
  options = {
    flake = flake-parts-lib.mkSubmoduleOptions {
      lib = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.unspecified;
        default = { };
        internal = true;
        description = "Utilities only to be used inside of this flake.";
      };
    };
  };

  config = {
    flake = {
      # This applies `nixpkgs.lib.recursiveUpdate` to a list of sets, instead of
      # just two.
      lib.recursiveMerge = sets: lib.lists.foldr lib.recursiveUpdate { } sets;
    };
  };
}
