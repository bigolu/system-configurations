{
  self,
  lib,
  ...
}:
{
  imports = [
    ./plugins
    ./xdg.nix
    ./missing-packages.nix
    ./meta-packages.nix
    ./partial-packages.nix
    ./misc.nix
  ];

  flake = {
    overlays.default = lib.composeManyExtensions [
      self.overlays.plugins
      self.overlays.xdg
      self.overlays.missingPackages
      self.overlays.metaPackages
      self.overlays.partialPackages
      self.overlays.misc
    ];
  };
}
