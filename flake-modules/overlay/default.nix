args@{
  lib,
  ...
}:
{
  flake = {
    lib.overlay =
      lib.trivial.pipe
        [
          ./plugins
          ./missing-packages.nix
          ./meta-packages.nix
          ./partial-packages.nix
          ./misc.nix
        ]
        [
          (map (path: import path args))
          lib.composeManyExtensions
        ];
  };
}
