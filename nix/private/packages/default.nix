let
  inherit (builtins) currentSystem;
  sources = import ../../../npins;
  lib = import "${sources.nixpkgs}/lib";
  context = {
    inherit sources lib;
    nixpkgs-stable = import sources.nixpkgs-stable {};
    utils = import ../utils.nix context;
  };
in
import sources.nixpkgs {
  system = currentSystem;
  # perf: To avoid fetching `sources` unnecessarily in CI, I don't use their
  # overlays. This way, I only have to fetch a source if I actually use one of its
  # packages.
  overlays =
    [
      (final: prev: {
        inherit (final.callPackage "${sources.gomod2nix}/builder" { }) buildGoApplication mkGoEnv mkVendorEnv;
        gomod2nix = final.callPackage sources.gomod2nix { };
      })
      (_: prev: {
        inherit (prev.callPackage "${sources.nix-darwin}/pkgs/nix-tools" { }) darwin-rebuild darwin-option darwin-version;
        darwin-uninstaller = prev.callPackage "${sources.nix-darwin}/pkgs/darwin-uninstaller" { };
      })
      (final: _: {nix-gl-host = final.callPackage sources.nix-gl-host {};})
      (_: prev: { inherit (prev.callPackage sources.home-manager {}) home-manager; })
      # An overlay is available, but to reuse their cache, they recommend you use
      # their package instead:
      # https://github.com/nix-community/neovim-nightly-overlay#to-use-the-overlay
      (_: _: { inherit ((import "${sources.neovim-nightly-overlay}/flake-compat.nix").packages.${currentSystem}) neovim; })
    ]
    ++ [
      (import ../../public-overlay)
      (import ./overlay context)
    ];
}
