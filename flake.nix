{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    flake-compat.url = "https://git.lix.systems/lix-project/flake-compat/archive/main.tar.gz";

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

    nix-gl-host-rs = {
      url = "github:arilotter/nix-gl-host-rs";
      # TODO: It doesn't build with my version of nixpkgs
      # inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";

    devshell-modules.url = "github:bigolu/devshell-modules";

    llm-agents.url = "github:numtide/llm-agents.nix";

    direnv-shell-hooks = {
      url = "github:bigolu/direnv-shell-hooks";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";

        # Remove development dependencies
        devshell.follows = "";
        devshell-modules.follows = "";
      };
    };

    git-auto-sync = {
      url = "github:bigolu/git-auto-sync";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";

        # Remove development dependencies
        devshell.follows = "";
        devshell-modules.follows = "";
      };
    };

    nix-portable-home = {
      url = "github:bigolu/nix-portable-home";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";

        # Remove development dependencies
        devshell.follows = "";
        devshell-modules.follows = "";
      };
    };

    nix-rootless-bundler = {
      url = "github:bigolu/nix-rootless-bundler";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
        flake-compat.follows = "flake-compat";

        # Remove development dependencies
        devshell.follows = "";
        devshell-modules.follows = "";
      };
    };

    cached-nix-shell = {
      url = "github:bigolu/cached-nix-shell";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
        flake-compat.follows = "flake-compat";

        # Remove development dependencies
        devshell.follows = "";
        devshell-modules.follows = "";
      };
    };

    blueprint = {
      url = "github:numtide/blueprint";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.blueprint {
      inherit inputs;
      prefix = "nix/outputs";
      nixpkgs = {
        overlays = [ (import ./nix/nixpkgs-overlay.nix) ];
        config = {
          # TODO: I should open an issue with the project for adding a license
          allowUnfreePredicate = pkg: pkg.pname == "camelcasemotion";
        };
      };
    };
}
