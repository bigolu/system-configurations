{ sources, ... }:
final: prev:
let
  myVimPluginPack = final.vimUtils.packDir {
    bigolu.start = with final.vimPlugins; [
      camelcasemotion
      dial-nvim
      lazy-lsp-nvim
      mini-nvim
      nvim-lightbulb
      nvim-lspconfig
      nvim-treesitter.withAllGrammars
      nvim-treesitter-context
      nvim-treesitter-endwise
      nvim-treesitter-textobjects
      nvim-ts-autotag
      splitjoin-vim
      treesj
      vim-abolish
      vim-caser
      vim-matchup
      # For indentexpr
      vim-nix
      vim-sleuth
    ];
  };
in
{
  inherit myVimPluginPack;

  vimPlugins = prev.vimPlugins // {
    vim-caser = final.vimUtils.buildVimPlugin {
      pname = "vim-caser";
      version = sources.vim-caser.revision;
      src = sources.vim-caser;
    };
  };

  fishPlugins = prev.fishPlugins // {
    fish-async-prompt = prev.fishPlugins.fish-async-prompt.overrideAttrs (_old: {
      version = sources.fish-async-prompt.revision;
      src = sources.fish-async-prompt;
    });
  };
}
