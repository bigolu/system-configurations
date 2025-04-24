{
  makePluginPackages,
  utils,
  ...
}:
final: prev:
let
  inherit (utils) toNixpkgsPname;

  vimPluginsFromFlake =
    let
      vimPluginRepositoryPrefix = "vim-plugin-";

      vimPluginBuilder =
        repositoryName: repositorySourceCode: date:
        final.vimUtils.buildVimPlugin {
          pname = toNixpkgsPname repositoryName;
          version = date;
          src = repositorySourceCode;
        };
    in
    makePluginPackages vimPluginRepositoryPrefix vimPluginBuilder;

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
      vim-indentwise
      vim-matchup
      # For indentexpr
      vim-nix
      vim-repeat
      vim-sleuth
    ];
  };
in
{
  inherit myVimPluginPack;
  vimPlugins = prev.vimPlugins // vimPluginsFromFlake;
}
