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
          ./xdg.nix
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
