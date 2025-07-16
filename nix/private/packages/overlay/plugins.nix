{ pins, ... }:
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

  # TODO: should be upstreamed to nixpkgs
  vimPlugins = prev.vimPlugins // {
    vim-caser = final.vimUtils.buildVimPlugin {
      pname = "vim-caser";
      version = pins.vim-caser.revision;
      src = pins.vim-caser;
    };
  };

  fishPlugins = prev.fishPlugins // {
    # TODO: They don't seem to be making releases anymore. I should check with the
    # author and possibly have nixpkgs track master instead.
    async-prompt = prev.fishPlugins.async-prompt.overrideAttrs (_old: {
      version = pins.fish-async-prompt.revision;
      src = pins.fish-async-prompt;
    });
  };
}
