let
  myInputs = (import ./nix/flake-compat.nix).inputs;
in
{
  # In pure evaluation mode, the current system can't be accessed
  system ? builtins.currentSystem,

  # It's recommended to override this for two reasons:
  #   - The nixpkgs repo is about 200 MB so multiple checkouts would take up a lot of
  #     space.
  #   - It takes a while to evaluate nixpkgs i.e. `import <nixpkgs> {}`. For this
  #     reason, unlike other inputs, we take an already-evaluated nixpkgs in addition
  #     to the source code.
  #
  # For more info: https://zimbatm.com/notes/1000-instances-of-nixpkgs
  nixpkgs ? import (overrides.nixpkgs or myInputs.nixpkgs) {
    localSystem = system;
    # We provide values for these to avoid using their non-deterministic defaults.
    config = {
      # TODO: I should open an issue with the project for adding a license
      allowUnfreePredicate = pkg: pkg.pname == "camelcasemotion";
    };
    overlays = [ ];
  },

  # Inputs to override. See flake.nix for the full list of inputs
  overrides ? { },
}:
let
  inputs = myInputs // overrides;
  # Use derivation-based fetchers from nixpkgs for all pins.
  pins = nixpkgs.lib.mapAttrs (_: pin: pin { pkgs = nixpkgs; }) (import ./npins);
in
import ./nix/make-outputs.nix {
  root = ./nix/outputs;
  inherit (nixpkgs) lib;
  inherit system;
  context = self: {
    # These are commonly used so lets make them easier to access by exposing them at
    # the top level instead of having to go through `inputs`.
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
      nix-gl-host.outputs = inputs.nix-gl-host.packages.${system}.default;
      devshell-modules.outputs = import inputs.devshell-modules;
      direnv-shell-hooks.outputs = (import "${inputs.direnv-shell-hooks}/nix/flake-compat.nix").outputs;
      git-auto-sync.outputs = (import "${inputs.git-auto-sync}/nix/flake-compat.nix").outputs;
      nix-portable-home.outputs =
        nixpkgs.callPackage "${inputs.nix-portable-home}/nix/outputs/legacyPackages/makePortableHome"
          { };
      nix-rootless-bundler.outputs =
        (import "${inputs.nix-rootless-bundler}/nix/flake-compat.nix").outputs;
      cached-nix-shell.outputs = (import "${inputs.cached-nix-shell}/nix/flake-compat.nix").outputs;
      devshell.outputs = import inputs.devshell {
        inherit nixpkgs;
        inputs = { inherit (inputs) nixpkgs; };
      };
      home-manager.outputs = (import inputs.home-manager { pkgs = nixpkgs; }) // {
        nix-darwin = "${inputs.home-manager}/nix-darwin";
      };
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
