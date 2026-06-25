{
  system ? builtins.currentSystem,
}:
import (import ../.).inputs.nixpkgs {
  localSystem = { inherit system; };
  config = { };
  overlays = import ./overlays/nixpkgs.nix;
}
