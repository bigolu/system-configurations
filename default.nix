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
    # We provide values for these to avoid using their non-deterministic defaults.
    config = { };
    overlays = [ ];
  },

  # Inputs to override. See flake.nix for the full list of inputs
  overrides ? { },
}:
let
  inputs = myInputs // overrides;

  pins = nixpkgs.lib.mapAttrs (
    name: pin:
    let
      # Use derivation-based fetchers from nixpkgs for all pins.
      nixpkgsPin = pin { pkgs = nixpkgs; };
    in
    if nixpkgs.lib.hasPrefix "config-file-validator-" name then
      # npins will fetch this input with `nixpkgs.fetchZip`. I want to set
      # `stripRoot = false` in the call to `fetchZip`, but I can't so instead I
      # override the postFetch hook and put the contents of the tar inside of a
      # single directory.
      nixpkgsPin.outPath.overrideAttrs (
        _finalAttrs: previousAttrs:
        let
          target = ''if [ $(ls -A "$unpackDir" | wc -l) != 1 ]; then'';
          makeDirectory = ''
            _new_root="$(mktemp --directory)"
            _tmp="$_new_root/tmp"
            mkdir "$_tmp"
            mv "$unpackDir/"* "$_tmp/"
            unpackDir="$_new_root"
          '';
        in
        {
          postFetch = nixpkgs.lib.replaceString target ''
            ${makeDirectory}
            ${target}
          '' previousAttrs.postFetch;
        }
      )
    else
      nixpkgsPin
  ) (import ./npins);
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
      nixpkgs-nixos.outputs = import inputs.nixpkgs-nixos {
        # We provide values for these to avoid using their non-deterministic defaults.
        config = { };
        overlays = [ ];
      };
      nixpkgs-npins.outputs = import inputs.nixpkgs-npins {
        # We provide values for these to avoid using their non-deterministic defaults.
        config = { };
        overlays = [ ];
      };
      gitignore.outputs = import inputs.gitignore { inherit (nixpkgs) lib; };
      nix-gl-host.outputs = import inputs.nix-gl-host { pkgs = nixpkgs; };
      # TODO: Use the npins in nixpkgs once it has this commit:
      # https://github.com/andir/npins/commit/afa9fe50cb0bff9ba7e9f7796892f71722b2180d
      npins.outputs = import inputs.npins { pkgs = self.inputs.nixpkgs-npins.outputs; };
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
