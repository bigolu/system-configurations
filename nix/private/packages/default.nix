context@{sources, system, outputs, private, ... }:
let
  nixpkgs = import sources.nixpkgs {
    overlays = [
      (import ./overlay context)
      (_: prev: {
        mkShellNoCC = outputs.packages.mkShellWrapper.override {
          # So we can override `mkShellNoCC` without causing infinite recursion
          inherit (prev) mkShellNoCC;
        };
      })
    ];
  };

  gomod2nix = nixpkgs.lib.makeScope nixpkgs.newScope (self: {
    gomod2nix = self.callPackage sources.gomod2nix.outPath { };
    inherit (self.callPackage "${sources.gomod2nix}/builder" { inherit (self) gomod2nix; }) buildGoApplication mkGoEnv mkVendorEnv;
  });
in
# perf: To avoid fetching `sources` unnecessarily in CI, I don't use their overlays.
# This way, I only have to fetch a source if I actually use one of its packages.
#
# perf: I'm intentionally not using an overlay so nixpkgs's fetchers can be used to
# fetch sources. Unlike the builtin fetchers, the ones from nixpkgs produce
# derivations so the fetching can be parallelized with other derivations.
nixpkgs // gomod2nix // outputs.packages // {
  inherit (nixpkgs.callPackage "${sources.nix-darwin}/pkgs/nix-tools" { }) darwin-rebuild darwin-option darwin-version;
  darwin-uninstaller = nixpkgs.callPackage "${sources.nix-darwin}/pkgs/darwin-uninstaller" { };

  nix-gl-host = nixpkgs.callPackage sources.nix-gl-host.outPath {};
  inherit (nixpkgs.callPackage sources.home-manager.outPath {}) home-manager;
  inherit ((import "${sources.neovim-nightly-overlay}/flake-compat.nix").packages.${system}) neovim;

  # TODO: belongs in a private package set
  # This is usually broken on unstable
  inherit (private.nixpkgs-stable) diffoscopeMinimal;
}
