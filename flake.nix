{
  description = "System configurations";

  outputs =
    inputs@{
      flake-parts,
      flake-utils,
      ...
    }:
    flake-parts.lib.mkFlake
      {
        inherit inputs;
        specialArgs.utils = import ./nix/utils.nix;
      }
      {
        imports = [ ./nix/flake/modules ];

        systems = with flake-utils.lib.system; [
          x86_64-linux
          x86_64-darwin
        ];

        perSystem =
          { system, ... }:
          {
            # In pure evaluation mode, `currentSystem` won't be available, but it
            # will be when the flake is evaluated impurely, like through
            # `flake/compat.nix`.
            _module.args.pkgs =
              let
                packages = import ./nix/packages.nix;
              in
              if builtins ? "currentSystem" then packages else packages system;
          };

        # For nixd:
        # https://github.com/nix-community/nixd/blob/c38702b17580a31e84c958b5feed3d8c7407f975/nixd/docs/configuration.md#options-options
        debug = true;
      };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.6.0";

    # There's a higher chance that something builds on stable, since stable only
    # provides conservative updates e.g. security patches, so I'll keep this just in
    # case.
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";

    stackline = {
      url = "github:AdamWagner/stackline";
      flake = false;
    };

    # TODO: I should do a sparse checkout to get the single Spoon I need.
    # issue: https://github.com/NixOS/nix/issues/5811
    spoons = {
      url = "github:Hammerspoon/Spoons";
      flake = false;
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gomod2nix = {
      url = "github:nix-community/gomod2nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

    nix-gl-host = {
      url = "github:numtide/nix-gl-host";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      # This flake's packages are available in a cache. I'm intentionally not setting
      # `inputs.nixpkgs.follows = "nixpkgs"`because if I did, then the packages
      # created by this flake would be different from the ones that they cached.
      inputs = {
        flake-compat.follows = "";
        flake-parts.follows = "flake-parts";
        git-hooks.follows = "";
        hercules-ci-effects.follows = "";
        treefmt-nix.follows = "";
      };
    };

    keyd = {
      url = "github:rvaiya/keyd";
      flake = false;
    };

    # Flake Utilities
    # --------------------------------------------------------------------------

    flake-compat.url = "git+https://git.lix.systems/lix-project/flake-compat";

    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # Fish Plugins
    # --------------------------------------------------------------------------

    # TODO: This plugin doesn't seem to be making releases anymore. I should check
    # with the author and possibly have nixpkgs track master instead.
    "fish-plugin-fish-async-prompt" = {
      url = "github:acomagu/fish-async-prompt";
      flake = false;
    };

    # Vim Plugins
    # --------------------------------------------------------------------------
    # TODO: Add these plugins to nixpkgs

    "vim-plugin-vim-caser" = {
      url = "github:arthurxavierx/vim-caser";
      flake = false;
    };

    # Follow Targets
    # --------------------------------------------------------------------------
    # These inputs are only here so I can set them as the target of a `follows`.

    systems.url = "github:nix-systems/default";
  };
}
