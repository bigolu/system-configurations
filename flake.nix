{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    flake-compat.url = "https://git.lix.systems/lix-project/flake-compat/archive/main.tar.gz";

    gomod2nix = {
      url = "github:nix-community/gomod2nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
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
      url = "github:arilotter/nix-gl-host-rs";
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

    # I would like to fetch this with npins, but it's not supported[1].
    #
    # [1]: https://github.com/andir/npins/issues/163
    openrgb-udev-rules = {
      url = "https://openrgb.org/releases/release_0.9/60-openrgb.rules";
      flake = false;
      type = "file";
    };

    # TODO: Remove when v1.4.0 reaches nixpkgs
    nix-fast-build = {
      url = "github:Mic92/nix-fast-build";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    inputs:
    inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        outputs = import ./. {
          inherit system;
          nixpkgs = inputs.nixpkgs.legacyPackages.${system};
          overrides = inputs;
        };
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
