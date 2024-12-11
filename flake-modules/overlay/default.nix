context@{
  lib,
  ...
}:
let
  overlayModules = [
    ./plugins
    ./missing-packages.nix
    ./partial-packages.nix
    ./misc.nix
  ];

  callOverlayModule = overlayModule: import overlayModule context;
  overlays = map callOverlayModule overlayModules;
  composedOverlays = lib.composeManyExtensions overlays;
in
{
  flake = {
    lib.overlay = composedOverlays;
  };
}
