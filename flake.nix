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

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    git-auto-check = {
      url = "github:bigolu/git-auto-check";
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
        flake-compat.follows = "flake-compat";

        # Remove development dependencies
        devshell.follows = "";
        devshell-modules.follows = "";
      };
    };

    nix-scene = {
      url = "github:bigolu/nix-scene";
      inputs = {
        nixpkgs.follows = "nixpkgs";
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

    home-manager-file-wrapper = {
      url = "github:bigolu/home-manager-file-wrapper";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";

        # Remove development dependencies
        devshell.follows = "";
        devshell-modules.follows = "";
      };
    };

    system-manager = {
      url = "github:numtide/system-manager";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
      };
    };
  };

  outputs =
    inputs:
    # Ensure the flake isn't considered a function[1].
    #
    # https://github.com/numtide/blueprint/issues/110
    removeAttrs (inputs.blueprint {
      inherit inputs;
      prefix = "nix/outputs";
      nixpkgs = import ./nix/nixpkgs-config.nix;
    }) [ "__functor" ];
}
