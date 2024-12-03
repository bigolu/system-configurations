# TODO: Trick renovate into working: "github:NixOS/nixpkgs/nixpkgs-unstable"
# Source: https://github.com/renovatebot/renovate/issues/29721
# fix: https://github.com/renovatebot/renovate/pull/31921
{
  description = "System configurations";

  outputs =
    inputs@{
      flake-parts,
      flake-utils,
      nixpkgs,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { self, ... }:
      {
        imports = [
          ./flake-modules/cache.nix
          ./flake-modules/nix-darwin
          ./flake-modules/overlay
          ./flake-modules/portable-home
          ./flake-modules/bundler
          ./flake-modules/home-manager
          ./flake-modules/lib.nix
          ./flake-modules/dev-shell
        ];

        flake = {
          lib.root = ./.;
        };

        systems = with flake-utils.lib.system; [
          x86_64-linux
          x86_64-darwin
        ];

        perSystem =
          { system, ... }:
          {
            _module.args.pkgs = import nixpkgs {
              inherit system;
              overlays = [ self.lib.overlay ];
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
    flake-compat.url = "https://flakehub.com/f/edolstra/flake-compat/1.tar.gz";
    flake-utils.url = "github:numtide/flake-utils";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nix-develop-gha = {
      url = "github:nicknovitski/nix-develop";
      inputs.nixpkgs.follows = "nixpkgs";
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
    neodev-nvim = {
      url = "github:folke/neodev.nvim";
      flake = false;
    };
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
