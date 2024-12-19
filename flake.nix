# TODO: Trick renovate into working: "github:NixOS/nixpkgs/nixpkgs-unstable"
# Source: https://github.com/renovatebot/renovate/issues/29721
# fix: https://github.com/renovatebot/renovate/pull/31921
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
        # This is the recommended way to provide internal utilities to flake
        # modules[1].
        #
        # [1]: https://github.com/hercules-ci/flake-parts/discussions/234#discussioncomment-9950293
        specialArgs.utils = import ./nix/utils.nix inputs;
      }
      (
        { self, ... }:
        {
          imports = [
            ./nix/flake-modules/checks
            ./nix/flake-modules/dev-shells.nix
            ./nix/flake-modules/packages.nix
            ./nix/flake-modules/bundlers.nix
            ./nix/flake-modules/home-configurations
            ./nix/flake-modules/darwin-configurations
            ./nix/flake-modules/overlays
            ./nix/flake-modules/public-flake-modules
          ];

          systems = with flake-utils.lib.system; [
            x86_64-linux
            x86_64-darwin
          ];

          # - For nixd[1]
          # - To get access to the flake's package set, i.e. the `pkgs` argument passed
          #   to perSystem[2], from outside the flake. See packages.nix for an example
          #   of how it gets accessed.
          #
          # [1]: https://github.com/nix-community/nixd/blob/c38702b17580a31e84c958b5feed3d8c7407f975/nixd/docs/configuration.md#options-options
          # [2]: https://flake.parts/module-arguments.html?highlight=pkgs#pkgs
          debug = true;

          perSystem =
            { system, ... }:
            {
              # - For the convenience of having my overlay already applied wherever I
              #   access pkgs.
              # - To avoid instantiating nixpkgs multiple times, which would lead to
              #   higher memory consumption and slower evaluation[1].
              #
              # [1]: https://zimbatm.com/notes/1000-instances-of-nixpkgs
              _module.args.pkgs = import inputs.nixpkgs {
                inherit system;
                overlays = [
                  inputs.gomod2nix.overlays.default
                  inputs.nix-darwin.overlays.default
                  (import ./nix/overlays/private inputs)
                ] ++ (builtins.attrValues self.overlays);
              };
            };
        }
      );

  inputs = {
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

    # Nix
    ########################################
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # There's a higher chance that something builds on stable, since stable only
    # provides conservative updates e.g. security patches, so I'll keep this just in
    # case.
    nixpkgs-stable.url = "https://flakehub.com/f/NixOS/nixpkgs/*.tar.gz";
    nix-flatpak.url = "https://flakehub.com/f/gmodena/nix-flatpak/*.tar.gz";
    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
    nix-darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
    gomod2nix = {
      url = "github:nix-community/gomod2nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    # Flake
    ########################################
    flake-compat.url = "https://flakehub.com/f/edolstra/flake-compat/*.tar.gz";
    flake-utils.url = "github:numtide/flake-utils";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # fish
    ########################################
    fish-plugin-autopair-fish = {
      url = "github:jorgebucaran/autopair.fish";
      flake = false;
    };
    fish-plugin-async-prompt = {
      url = "github:acomagu/fish-async-prompt";
      flake = false;
    };
    fish-plugin-completion-sync = {
      url = "github:pfgray/fish-completion-sync";
      flake = false;
    };
    fish-plugin-done = {
      url = "github:franciscolourenco/done";
      flake = false;
    };

    # vim
    ########################################
    # I'm intentionally not using `inputs.nixpkgs.follows` because if I did, then the
    # neovim created by this flake would be different from the one that they cache
    # and then I'd have to build it.
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
    };
    vim-plugin-bullets-vim = {
      url = "github:bullets-vim/bullets.vim";
      flake = false;
    };
    vim-plugin-CamelCaseMotion = {
      url = "github:bkad/CamelCaseMotion";
      flake = false;
    };
    vim-plugin-dial-nvim = {
      url = "github:monaqa/dial.nvim";
      flake = false;
    };
    vim-plugin-direnv-vim = {
      url = "github:direnv/direnv.vim";
      flake = false;
    };
    vim-plugin-fidget-nvim = {
      url = "github:j-hui/fidget.nvim";
      flake = false;
    };
    vim-plugin-lazy-lsp-nvim = {
      url = "github:dundalek/lazy-lsp.nvim";
      flake = false;
    };
    vim-plugin-mini-nvim = {
      url = "github:echasnovski/mini.nvim";
      flake = false;
    };
    vim-plugin-nvim-autopairs = {
      url = "github:windwp/nvim-autopairs";
      flake = false;
    };
    vim-plugin-nvim-lightbulb = {
      url = "github:kosayoda/nvim-lightbulb";
      flake = false;
    };
    vim-plugin-nvim-lspconfig = {
      url = "github:neovim/nvim-lspconfig";
      flake = false;
    };
    vim-plugin-nvim-treesitter = {
      url = "github:nvim-treesitter/nvim-treesitter";
      flake = false;
    };
    vim-plugin-nvim-treesitter-context = {
      url = "github:nvim-treesitter/nvim-treesitter-context";
      flake = false;
    };
    vim-plugin-nvim-treesitter-endwise = {
      # Use this fork until this PR is merged:
      # https://github.com/RRethy/nvim-treesitter-endwise/pull/42
      url = "github:metiulekm/nvim-treesitter-endwise";
      flake = false;
    };
    vim-plugin-nvim-treesitter-textobjects = {
      url = "github:nvim-treesitter/nvim-treesitter-textobjects";
      flake = false;
    };
    vim-plugin-nvim-ts-autotag = {
      url = "github:windwp/nvim-ts-autotag";
      flake = false;
    };
    vim-plugin-SchemaStore-nvim = {
      url = "github:b0o/SchemaStore.nvim";
      flake = false;
    };
    vim-plugin-splitjoin-vim = {
      url = "github:AndrewRadev/splitjoin.vim";
      flake = false;
    };
    vim-plugin-treesj = {
      url = "github:Wansmer/treesj";
      flake = false;
    };
    vim-plugin-vim-abolish = {
      url = "github:tpope/vim-abolish";
      flake = false;
    };
    vim-plugin-vim-caser = {
      url = "github:arthurxavierx/vim-caser";
      flake = false;
    };
    vim-plugin-vim-indentwise = {
      url = "github:jeetsukumaran/vim-indentwise";
      flake = false;
    };
    vim-plugin-vim-matchup = {
      url = "github:andymass/vim-matchup";
      flake = false;
    };
    vim-plugin-vim-nix = {
      url = "github:LnL7/vim-nix";
      flake = false;
    };
    vim-plugin-vim-plug = {
      url = "github:junegunn/vim-plug";
      flake = false;
    };
    vim-plugin-vim-repeat = {
      url = "github:tpope/vim-repeat";
      flake = false;
    };
    vim-plugin-vim-signify = {
      url = "github:mhinz/vim-signify";
      flake = false;
    };
    vim-plugin-vim-sleuth = {
      url = "github:tpope/vim-sleuth";
      flake = false;
    };
    vim-plugin-Navigator-nvim = {
      url = "github:numToStr/Navigator.nvim";
      flake = false;
    };
  };
}
