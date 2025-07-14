let
  inherit (import ./flake/compat.nix) inputs;

  getPackagesForSystem =
    system:
    import inputs.nixpkgs {
      inherit system;
      # perf: To avoid fetching inputs unnecessarily in CI, I don't use their
      # overlays. This way, I only have to fetch an input if I actually use one of
      # its packages.
      overlays =
        [
          (final: prev: {
            inherit ((import "${inputs.neovim-nightly-overlay}/flake-compat.nix").packages.${system}) neovim;
            nix-gl-host = final.callPackage inputs.nix-gl-host { };
            inherit (prev.callPackage inputs.home-manager { }) home-manager;

            inherit (prev.callPackage "${inputs.nix-darwin}/pkgs/nix-tools" { })
              darwin-rebuild
              darwin-option
              darwin-version
              ;
            darwin-uninstaller = prev.callPackage "${inputs.nix-darwin}/pkgs/darwin-uninstaller" { };

            inherit (final.callPackage "${inputs.gomod2nix}/builder" { })
              buildGoApplication
              mkGoEnv
              mkVendorEnv
              ;
            gomod2nix = final.callPackage inputs.gomod2nix { };
          })
        ]
        ++ [
          (import ./public-overlay)
          (import ./overlay inputs)
        ];
    };
in
# In pure evaluation mode, currentSystem won't be available so the system will need
# to be passed in.
if builtins ? "currentSystem" then
  getPackagesForSystem builtins.currentSystem
else
  getPackagesForSystem
