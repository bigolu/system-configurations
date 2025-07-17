context@{
  pins,
  system,
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
#
# perf: I'm intentionally not using an overlay so nixpkgs's fetchers can be used to
# fetch pins. Unlike the builtin fetchers, the ones from nixpkgs produce derivations
# so the fetching can be parallelized with other derivations, or avoided altogether
# if a substitute is available.
nixpkgs
// pins.gomod2nix.outputs
// outputs.packages
// {
  inherit (pins.home-manager.outputs) home-manager;
  nix-gl-host = pins.nix-gl-host.outputs;
  npins = pins.npins.outputs;

  inherit (pins.nix-darwin.outputs)
    darwin-rebuild
    darwin-option
    darwin-version
    darwin-uninstaller
    ;


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

  neovim =
    let
      nightlyNoevim = pins.neovim-nightly-overlay.outputs.packages.${system}.neovim;

      dependencies = nixpkgs.symlinkJoin {
        pname = "neovim-dependencies";
        version = unstableVersion;
        # to format comments
        paths = [ nixpkgs.par ];
      };

      wrappedNeovim = nixpkgs.symlinkJoin {
        pname = "my-${nightlyNoevim.pname}";
        inherit (nightlyNoevim) version;
        paths = [ nightlyNoevim ];
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
    lib.recursiveUpdate nightlyNoevim wrappedNeovim;
}
