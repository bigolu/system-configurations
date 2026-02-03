{
  pkgs,
  pins,
  ...
}:
let
  inherit (pkgs)
    linkFarm
    neovim
    vimUtils
    vimPlugins
    ;
in
{
  home.packages = [
    neovim
    (linkFarm "my-vim-pack" {
      # Put the pack under share/ so neovim can automatically find it
      "share/nvim/site" = vimUtils.packDir {
        bigolu.start = with vimPlugins; [
          camelcasemotion
          dial-nvim
          lazy-lsp-nvim
          mini-nvim
          nvim-lightbulb
          nvim-lspconfig
          nvim-treesitter.withAllGrammars
          nvim-treesitter-context
          # TODO: Originally, it used `nvim-treesitter-legacy`, but you can't have
          # multiple versions of `nvim-treesitter` in use at once.
          (nvim-treesitter-endwise.overrideAttrs { dependencies = [ nvim-treesitter ]; })
          nvim-treesitter-textobjects
          nvim-ts-autotag
          treesj
          vim-abolish
          vim-matchup
          # For indentexpr
          vim-nix
          vim-sleuth

          # TODO: should be upstreamed to nixpkgs
          (vimUtils.buildVimPlugin {
            pname = "vim-caser";
            version = pins.vim-caser.revision;
            src = pins.vim-caser;
          })
        ];
      };
    })
  ];

  repository.xdg.configFile."nvim".source = "neovim";
}
