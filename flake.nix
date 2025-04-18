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
        specialArgs.utils = import ./nix/utils.nix inputs;
      }
      (
        { self, ... }:
        {
          imports = [
            ./nix/flake/modules/checks.nix
            ./nix/flake/modules/dev-shells
            ./nix/flake/modules/packages.nix
            ./nix/flake/modules/bundlers.nix
            ./nix/flake/modules/home-configurations
            ./nix/flake/modules/darwin-configurations
            ./nix/flake/modules/overlays
            ./nix/flake/modules/public-modules
          ];

          systems = with flake-utils.lib.system; [
            x86_64-linux
            x86_64-darwin
          ];

          # - For nixd[1]
          # - To get access to the flake's package set, i.e. the `pkgs` argument
          #   passed to perSystem[2], from outside the flake. See
          #   flake/internal-package-set.nix for an example of how it gets accessed.
          #
          # [1]: https://github.com/nix-community/nixd/blob/c38702b17580a31e84c958b5feed3d8c7407f975/nixd/docs/configuration.md#options-options
          # [2]: https://flake.parts/module-arguments.html?highlight=pkgs#pkgs
          debug = true;

          perSystem =
            { system, inputs', ... }:
            let
              privateOverlay = import ./nix/overlay inputs;
              publicOverlays = builtins.attrValues self.overlays;

              makeOverlay =
                {
                  input,
                  package ? input,
                }:
                _final: _prev: { ${package} = inputs'.${input}.packages.${package}; };
            in
            {
              _module.args.pkgs = import inputs.nixpkgs {
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
                  ++ publicOverlays
                  ++ [ privateOverlay ];
              };
            };
        }
      );

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    # There's a higher chance that something builds on stable, since stable only
    # provides conservative updates e.g. security patches, so I'll keep this just in
    # case.
    nixpkgs-stable.url = "https://flakehub.com/f/NixOS/nixpkgs/*.tar.gz";

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
      url = "github:Mic92/nix-index-database";
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

    isd = {
      url = "github:isd-project/isd";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
        nix-appimage.follows = "";
        systemd-nix.follows = "";
      };
    };

    ghostty = {
      url = "github:ghostty-org/ghostty";
      inputs = {
        nixpkgs-stable.follows = "nixpkgs-stable";
        nixpkgs-unstable.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
        flake-compat.follows = "";
      };
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
