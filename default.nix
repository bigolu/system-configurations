let
  flakeInputs = (import ./nix/flake-compat.nix).inputs;
in
{
  # In flake pure evaluation mode, the current system can't be accessed so we'll take
  # it as a parameter.
  system ? builtins.currentSystem,

  # It's recommended to override this for two reasons:
  #   - The nixpkgs repo is about 200 MB so multiple checkouts would take up a lot
  #     of space.
  #   - It takes about a second to evaluate nixpkgs i.e. `import <nixpkgs> {}`.
  #     For this reason, unlike other inputs, we take an already-evaluated nixpkgs
  #     instead of the source code.
  #
  # For more info: https://zimbatm.com/notes/1000-instances-of-nixpkgs
  nixpkgs ? flakeInputs.nixpkgs.legacyPackages.${system},

  gomod2nix ? flakeInputs.gomod2nix,
  gitignore ? flakeInputs.gitignore,
}:
let
  pins =
    builtins.mapAttrs
      # Use derivation-based fetchers from nixpkgs for all pins.
      (_name: pin: pin { pkgs = nixpkgs; })
      (import ./npins);
in
import ./nix/make-outputs.nix {
  root = ./nix/outputs;
  inherit (nixpkgs) lib;
  inherit system;
  context = self: {
    # These are commonly used so lets make them easier to access by exposing them at
    # the top level.
    inherit nixpkgs;
    inherit (nixpkgs) lib;

    utils = import ./nix/utils self;
    packages = import ./nix/packages;

    # Our inputs and their outputs, with any overrides applied
    inputs =
      pins
      // flakeInputs
      // {
        gitignore = gitignore // {
          outputs = import gitignore { inherit (nixpkgs) lib; };
        };
        home-manager = flakeInputs.home-manager // {
          outputs = (import flakeInputs.home-manager { pkgs = nixpkgs; }) // {
            nix-darwin = "${flakeInputs.home-manager}/nix-darwin";
          };
        };
        nix-gl-host = flakeInputs.nix-gl-host // {
          outputs = import flakeInputs.nix-gl-host { pkgs = nixpkgs; };
        };
        # TODO: Use the npins in nixpkgs once it has this commit:
        # https://github.com/andir/npins/commit/afa9fe50cb0bff9ba7e9f7796892f71722b2180d
        npins = flakeInputs.npins // {
          outputs = import flakeInputs.npins { pkgs = nixpkgs; };
        };
        gomod2nix = gomod2nix // {
          outputs = nixpkgs.lib.makeScope nixpkgs.newScope (self: {
            gomod2nix = self.callPackage gomod2nix.outPath { };
            inherit (self.callPackage "${gomod2nix}/builder" { inherit (self) gomod2nix; })
              buildGoApplication
              mkGoEnv
              mkVendorEnv
              ;
          });
        };
        nixpkgs = flakeInputs.nixpkgs // {
          outputs = nixpkgs;
        };
        nix-darwin = flakeInputs.nix-darwin // {
          outputs = (import flakeInputs.nix-darwin { pkgs = nixpkgs; }) // {
            darwinSystem = nixpkgs.lib.pipe "${flakeInputs.nix-darwin}/flake.nix" [
              import
              (
                flake:
                nixpkgs.lib.fix (
                  self:
                  flake.outputs {
                    inherit self;
                    nixpkgs = flakeInputs.nixpkgs // {
                      inherit (nixpkgs) lib;
                    };
                  }
                )
              )
              (outputs: outputs.lib.darwinSystem)
            ];
          };
        };
      };
  };
}
