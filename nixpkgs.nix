# I use this in my nix-shell shebang scripts so they can use the same version of
# nixpkgs as my flake, with my overlay applied.
originalArgs:
let
  flake = import ./default.nix;

  originalArgsWithFlakeOverlay = originalArgs // {
    overlays = (originalArgs.overlays or [ ]) ++ [ flake.lib.overlay ];
  };
in
import flake.inputs.nixpkgs originalArgsWithFlakeOverlay
