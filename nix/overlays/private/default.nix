inputs: final: prev:
let
  inherit (inputs.nixpkgs) lib;
  utils = import ../../utils.nix inputs;

  composedOverlays =
    lib.trivial.pipe
      [
        ./plugins
        ./missing-packages.nix
        ./partial-packages.nix
        ./misc.nix
      ]
      [
        (map (path: import path { inherit inputs utils; }))
        lib.composeManyExtensions
      ];
in
composedOverlays final prev
