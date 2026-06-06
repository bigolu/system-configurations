nixpkgs:
# Use derivation-based fetchers from nixpkgs for all pins.
nixpkgs.lib.mapAttrs (_: pin: pin { pkgs = nixpkgs; }) (import ./npins)
