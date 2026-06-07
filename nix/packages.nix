import (import ./flake-compat.nix).inputs.nixpkgs {
  config = { };
  overlays = import ./overlays/nixpkgs.nix;
}
