{
  # Why we use a flake to track our evaluation inputs:
  #   - Flakes will track inputs recursively which makes it easy to create GC roots
  #     for all of them.
  #   - It allows flake users to override our inputs using `follows` and vice-versa.
  #     Though we use our inputs' stable nix interfaces, we still need to use
  #     `follows` since we make GC roots for all of the inputs in `flake.lock`.
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    flake-compat.url = "git+https://git.lix.systems/lix-project/flake-compat";

    gomod2nix = {
      url = "github:nix-community/gomod2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.6.0";

    nix-gl-host = {
      url = "github:numtide/nix-gl-host";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";

    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-sweep = {
      url = "github:jzbor/nix-sweep";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # This is only used for bundlers since the nix CLI only accepts a flakeref for
  # `--bundler`.
  outputs =
    _:
    let
      # Everything below was taken from https://github.com/numtide/flake-utils

      systems = [
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      # Builds a map from <attr>=value to <attr>.<system>=value for each system.
      eachSystem = eachSystemOp (
        # Merge outputs for each system.
        f: attrs: system:
        let
          ret = f system;
        in
        builtins.foldl' (
          attrs: key:
          attrs
          // {
            ${key} = (attrs.${key} or { }) // {
              ${system} = ret.${key};
            };
          }
        ) attrs (builtins.attrNames ret)
      ) systems;

      # Applies a merge operation across systems.
      eachSystemOp =
        op: systems: f:
        builtins.foldl' (op f) { } (
          if !builtins ? currentSystem || builtins.elem builtins.currentSystem systems then
            systems
          else
            # Add the current system if the --impure flag is used.
            systems ++ [ builtins.currentSystem ]
        );
    in
    eachSystem (
      system:
      let
        outputs = import ./. { inherit system; };
      in
      {
        bundlers = rec {
          inherit (outputs.bundlers) rootless;
          default = rootless;
        };

        apps.default = {
          type = "app";
          program = "${outputs.packages.init-config}/bin/init-config";
        };
      }
    );
}
