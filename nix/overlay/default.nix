inputs: final: prev:
let
  inherit (inputs.nixpkgs) lib;
  inherit (lib) pipe composeManyExtensions;

  utils = import ../utils.nix inputs;

  composedOverlays =
    pipe
      [
        ./plugins
        ./missing-packages.nix
        ./partial-packages.nix
        ./misc.nix
        ./gl-wrappers.nix
      ]
      [
        (map (path: import path { inherit inputs utils; }))
        composeManyExtensions
      ];
in
composedOverlays final prev
