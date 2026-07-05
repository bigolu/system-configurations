{ pkgs, pins, ... }:
let
  inherit (pkgs)
    linkFarm
    neovim-unwrapped
    vimUtils
    vimPlugins
    ;
in
{
  home.packages = [
    neovim-unwrapped
    (linkFarm "my-vim-pack" {
      # Put the pack under share/ so neovim can automatically find it
      "share/nvim/site" = vimUtils.packDir {
        bigolu.start = with vimPlugins; [
          dial-nvim
          lazy-lsp-nvim
          mini-nvim
          nvim-lightbulb
          nvim-lspconfig
          nvim-treesitter.withAllGrammars
          nvim-treesitter-endwise
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

  fileWrapper.xdg.configFile."nvim".source = "neovim";
}
