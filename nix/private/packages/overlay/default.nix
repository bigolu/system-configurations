context@{ lib, ... }:
final: prev:
let
  inherit (lib) pipe composeManyExtensions;

  composedOverlays =
    pipe
      [
        ./plugins
        ./missing-packages.nix
        ./partial-packages.nix
        ./misc.nix
        ./gl-wrappers.nix
        ./fixes.nix
      ]
      [
        (map (path: import path context))
        composeManyExtensions
      ];
in
composedOverlays final prev
