{ inputs, ... }:
{
  imports = [
    ./plugins
    ./missing-packages.nix
    ./partial-packages.nix
    ./misc.nix
  ];

  flake.lib.overlays = {
    nix-darwin = inputs.nix-darwin.overlays.default;
    gomod2nix = inputs.gomod2nix.overlays.default;
  };
}
