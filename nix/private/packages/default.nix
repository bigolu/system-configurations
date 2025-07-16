context@{
  pins,
  system,
  outputs,
  private,
  gomod2nix,
  ...
}:
let
  nixpkgs = import pins.nixpkgs {
    overlays = [ (import ./overlay context) ];
  };
in
# perf: To avoid fetching `pins` unnecessarily in CI, I don't use their overlays.
# This way, I only have to fetch a source if I actually use one of its packages.
#
# perf: I'm intentionally not using an overlay so nixpkgs's fetchers can be used to
# fetch pins. Unlike the builtin fetchers, the ones from nixpkgs produce derivations
# so the fetching can be parallelized with other derivations, or avoided altogether
# if a substitute is available.
nixpkgs
// gomod2nix
// outputs.packages
// {
  inherit (nixpkgs.callPackage "${pins.nix-darwin}/pkgs/nix-tools" { })
    darwin-rebuild
    darwin-option
    darwin-version
    ;
  darwin-uninstaller = nixpkgs.callPackage "${pins.nix-darwin}/pkgs/darwin-uninstaller" { };

  nix-gl-host = nixpkgs.callPackage pins.nix-gl-host.outPath { };
  inherit (nixpkgs.callPackage pins.home-manager.outPath { }) home-manager;
  inherit ((import "${pins.neovim-nightly-overlay}/flake-compat.nix").packages.${system}) neovim;

  # TODO: belongs in a private package set
  # This is usually broken on unstable
  inherit (private.nixpkgs-stable) diffoscopeMinimal;
  nix-shell-interpreter = outputs.packages.nix-shell-interpreter.override {
    interpreter = nixpkgs.bash-script;
  };
  mkShellNoCC = outputs.packages.mkShellWrapper.override {
    # So we can override `mkShellNoCC` without causing infinite recursion
    inherit (nixpkgs) mkShellNoCC;
  };
  dumpNixShellShebang = outputs.packages.dumpNixShellShebang.override {
    inherit (private) pkgs;
  };
  npins = private.pkgs.callPackage "${pins.npins}/npins.nix" {};
}
