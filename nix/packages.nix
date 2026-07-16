{
  system ? builtins.currentSystem,
}:
import (import ../.).inputs.nixpkgs (
  (import ./nixpkgs-config.nix) // { localSystem = { inherit system; }; }
)
