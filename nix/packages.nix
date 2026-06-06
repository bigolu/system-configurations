import (import ./flake-compat.nix).inputs.nixpkgs {
  config = { };
  overlays = [ (import ./nixpkgs-overlay.nix) ];
}
