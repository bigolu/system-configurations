let
  myInputs = (import ./nix/flake-compat.nix).inputs;
in
{
  # In pure evaluation mode, the current system can't be accessed so we'll take
  # it as a parameter.
  system ? builtins.currentSystem,

  # It's recommended to override this for two reasons:
  #   - The nixpkgs repo is about 200 MB so multiple checkouts would take up a lot
  #     of space.
  #   - It takes about a second to evaluate nixpkgs i.e. `import <nixpkgs> {}`.
  #     For this reason, unlike other inputs, we take an already-evaluated nixpkgs
  #     instead of just the source code.
  #
  # For more info: https://zimbatm.com/notes/1000-instances-of-nixpkgs
  nixpkgs ? import myInputs.nixpkgs {
    # We provide values for these to avoid using their non-deterministic defaults.
    config = { };
    overlays = [ ];
  },

  # Inputs to override. See flake.nix for the full list of inputs
  overrides ? { },
}:
let
  inputs = myInputs // overrides;

  pins =
    nixpkgs.lib.mapAttrs
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
    # Using this variable name so nixd can provide autocomplete, documentation, etc.
    pkgs = import ./nix/packages;
    inherit pins;

    # Combine our inputs with their outputs
    inputs = nixpkgs.lib.recursiveUpdate inputs {
      nixpkgs.outputs = nixpkgs;
      gitignore.outputs = import inputs.gitignore { inherit (nixpkgs) lib; };
      nix-gl-host.outputs = import inputs.nix-gl-host { pkgs = nixpkgs; };
      # TODO: Use the npins in nixpkgs once it has this commit:
      # https://github.com/andir/npins/commit/afa9fe50cb0bff9ba7e9f7796892f71722b2180d
      npins.outputs = import inputs.npins { pkgs = nixpkgs; };
      nix-mk-shell-bin.outputs.lib.mkShellBin = import "${inputs.nix-mk-shell-bin}/make.nix";
      devshell.outputs = import inputs.devshell {
        inherit nixpkgs;
        inputs = { inherit (inputs) nixpkgs; };
      };
      home-manager.outputs = (import inputs.home-manager { pkgs = nixpkgs; }) // {
        nix-darwin = "${inputs.home-manager}/nix-darwin";
      };
      gomod2nix.outputs = nixpkgs.lib.makeScope nixpkgs.newScope (self: {
        gomod2nix = self.callPackage inputs.gomod2nix.outPath { };
        inherit (self.callPackage "${inputs.gomod2nix}/builder" { inherit (self) gomod2nix; })
          buildGoApplication
          mkGoEnv
          mkVendorEnv
          ;
      });
      nix-darwin.outputs = (import inputs.nix-darwin { pkgs = nixpkgs; }) // {
        darwinSystem = nixpkgs.lib.pipe "${inputs.nix-darwin}/flake.nix" [
          import
          (
            flake:
            nixpkgs.lib.fix (
              self:
              flake.outputs {
                inherit self;
                nixpkgs = inputs.nixpkgs // {
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
}
