context@{ lib, ... }:
final: prev:
let
  inherit (lib) pipe composeManyExtensions;

  composedOverlays =
    pipe
      [
        ./plugins.nix
        ./missing-packages.nix
        ./partial-packages.nix
        ./misc.nix
      ]
      [
        (map (path: import path context))
        composeManyExtensions
      ];
in
composedOverlays final prev
