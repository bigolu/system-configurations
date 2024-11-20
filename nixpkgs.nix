# I use point nix-path.nixpkgs to this file so my nix-shell shebang scripts can use
# the same version of nixpkgs as my flake, and have my overlays applied.
args:
let
  flake = import ./default.nix;
  inherit (flake.lib) overlay;
  inherit (flake.inputs) nixpkgs;
in
import nixpkgs (args // { overlays = args.overlays or [ ] ++ [ overlay ]; })
