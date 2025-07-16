context@{
  pins,
  system,
  outputs,
  private,
  gomod2nix,
  pkgs,
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
  inherit (pins.home-manager.outputs) home-manager;
  inherit (import pins.nix-darwin { inherit pkgs; }) darwin-rebuild darwin-option darwin-version darwin-uninstaller;
  nix-gl-host = import pins.nix-gl-host { inherit pkgs; };
  inherit ((import "${pins.neovim-nightly-overlay}/flake-compat.nix").packages.${system}) neovim;
  # TODO: Use the npins in nixpkgs once it has this commit:
  # https://github.com/andir/npins/commit/afa9fe50cb0bff9ba7e9f7796892f71722b2180d
  npins = import pins.npins { inherit pkgs; };

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
}
