context@{
  pins,
  outputs,
  private,
  lib,
  ...
}:
let
  inherit (private.utils) unstableVersion;

  nixpkgs = import pins.nixpkgs {
    overlays = [ (import ./overlay context) ];
  };
in
# perf: To avoid fetching `pins` unnecessarily in CI, I don't use their overlays.
# This way, I only have to fetch a source if I actually use one of its packages.
nixpkgs
// pins.gomod2nix.outputs
// outputs.packages
// {
  inherit (pins.home-manager.outputs) home-manager;
  npins = pins.npins.outputs;

  inherit (pins.nix-darwin.outputs)
    darwin-rebuild
    darwin-option
    darwin-version
    darwin-uninstaller
    ;

  # This is usually broken on unstable
  inherit (pins.nixpkgs-stable.outputs) diffoscopeMinimal;

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

  neovim =
    let
      oldNeovim = nixpkgs.neovim-unwrapped;

      dependencies = nixpkgs.symlinkJoin {
        pname = "neovim-dependencies";
        version = unstableVersion;
        # to format comments
        paths = [ nixpkgs.par ];
      };

      wrappedNeovim = nixpkgs.symlinkJoin {
        pname = "my-${oldNeovim.pname}";
        inherit (oldNeovim) version;
        paths = [ oldNeovim ];
        nativeBuildInputs = [ nixpkgs.makeWrapper ];
        postBuild = ''
          # PARINIT: The par manpage recommends using this value if you want
          # to start using par, but aren't familiar with how par works so
          # until I learn more, I'll use this value.
          wrapProgram $out/bin/nvim \
            --set PARINIT 'rTbgqR B=.\,?'"'"'_A_a_@ Q=_s>|' \
            --prefix PATH : ${dependencies}/bin
        '';
      };
    in
    # Merge with the original package to retain attributes like meta
    lib.recursiveUpdate oldNeovim wrappedNeovim;
}
