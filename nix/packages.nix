let
  getPackagesForSystem =
    system:
    let
      inherit (import ./flake/compat.nix) inputs;

      privateOverlay = import ./overlay inputs;
      publicOverlay = import ./public-overlay;

      makeOverlay =
        {
          input,
          package ? input,
        }:
        _final: _prev: { ${package} = inputs.${input}.packages.${system}.${package}; };
    in
    import inputs.nixpkgs {
      inherit system;
      overlays =
        [
          inputs.gomod2nix.overlays.default
          inputs.nix-darwin.overlays.default
          inputs.nix-gl-host.overlays.default
          inputs.ghostty.overlays.default
          (makeOverlay { input = "home-manager"; })
          (makeOverlay { input = "isd"; })
          # An overlay is available, but to reuse their cache, they
          # recommend you use their package instead:
          # https://github.com/nix-community/neovim-nightly-overlay#to-use-the-overlay
          (makeOverlay {
            input = "neovim-nightly-overlay";
            package = "neovim";
          })
        ]
        ++ [
          publicOverlay
          privateOverlay
        ];
    };
in
# In pure evaluation mode, currentSystem won't be available so the system will need
# to be passed in.
if builtins ? "currentSystem" then
  getPackagesForSystem builtins.currentSystem
else
  getPackagesForSystem
