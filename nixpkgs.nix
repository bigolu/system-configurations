# I add this file to the NIX_PATH as 'nixpkgs' so my nix-shell shebang scripts
# can use the same version of nixpkgs as my flake, with my overlay applied.
originalArgs:
let
  flake = import ./default.nix;

  originalArgsWithFlakeOverlay =
    let
      originalOverlaysWithFlakeOverlay =
        let
          originalOverlays = originalArgs.overlays or [ ];
        in
        originalOverlays ++ [ flake.lib.overlay ];
    in
    originalArgs // { overlays = originalOverlaysWithFlakeOverlay; };
in
import flake.inputs.nixpkgs originalArgsWithFlakeOverlay
