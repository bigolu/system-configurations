# TODO: Trick renovate into working: "github:NixOS/nixpkgs/nixpkgs-unstable"
# Source: https://github.com/renovatebot/renovate/issues/29721
{
  description = "Biggie's host configurations";

  nixConfig = {
    # SYNC: OUR_CACHES
    extra-substituters = "https://cache.garnix.io https://bigolu.cachix.org";
    extra-trusted-public-keys = "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g= bigolu.cachix.org-1:AJELdgYsv4CX7rJkuGu5HuVaOHcqlOgR07ZJfihVTIw=";
  };

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
          ./flake-modules/smart-plug.nix
          ./flake-modules/dev-shell
          ./flake-modules/bootstrap.nix
        ];

        # For nixd
        debug = true;

        systems = with flake-utils.lib.system; [
          x86_64-linux
          x86_64-darwin
        ];

        perSystem =
          { system, ... }:
          {
            _module.args.pkgs = import nixpkgs {
              inherit system;
              overlays = [ self.overlays.default ];
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
    # TODO: I get an error when i try to build the wezterm flake on darwin so
    # I'll use the one from nixpkgs
    #
    # TODO: When this gets resolved, I can remove the revision pin:
    # https://github.com/NixOS/nixpkgs/issues/239384
    nixpkgs-for-wezterm-darwin.url = "github:nixos/nixpkgs?rev=ff0a5a776b56e0ca32d47a4a47695452ec7f7d80";
    nix-flatpak.url = "https://flakehub.com/f/gmodena/nix-flatpak/*.tar.gz";

    # nix
    ########################################
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
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
    nix-xdg = {
      url = "github:infinisil/nix-xdg";
      flake = false;
    };
    gomod2nix = {
      url = "github:nix-community/gomod2nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
    flake-utils.url = "github:numtide/flake-utils";
    # TODO: I get an error when I try to upgrade this
    flake-parts.url = "github:hercules-ci/flake-parts?rev=b253292d9c0a5ead9bc98c4e9a26c6312e27d69f";
    # TODO: A test fails when I try to upgrade
    nixpkgs-for-diffoscope.url = "github:nixos/nixpkgs?rev=fd16bb6d3bcca96039b11aa52038fafeb6e4f4be";
    # UNFREE
    # IMPURE
    # TODO: I think I can make its auto-detection pure by having the nixGL
    # executable be a script that reads /proc/driver at runtime, instead of at
    # buildtime:
    # https://github.com/nix-community/nixGL/blob/489d6b095ab9d289fe11af0219a9ff00fe87c7c5/nixGL.nix#L225C14-L225C72
    nixgl = {
      url = "github:guibou/nixGL";
      # Per the readme, nixgl needs to use the same nixpkgs as the program it's
      # wrapping:
      # https://github.com/nix-community/nixGL?tab=readme-ov-file#directly-run-nixgl
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-compat.url = "https://flakehub.com/f/edolstra/flake-compat/1.tar.gz";

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
    vim-plugin-conform-nvim = {
      url = "github:stevearc/conform.nvim";
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
    vim-plugin-firenvim = {
      url = "github:glacambre/firenvim";
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
      url = "github:lvim-tech/nvim-lightbulb";
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
      url = "github:RRethy/nvim-treesitter-endwise";
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
