{
  makePluginPackages,
  private,
  ...
}:
final: prev:
let
  inherit (private.utils) toNixpkgsPname;

  vimPluginsFromFlake =
    let
      vimPluginRepositoryPrefix = "vim-plugin-";

      vimPluginBuilder =
        repositoryName: repositorySource: version:
        final.vimUtils.buildVimPlugin {
          pname = toNixpkgsPname repositoryName;
          inherit version;
          src = repositorySource;
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
      vim-matchup
      # For indentexpr
      vim-nix
      vim-sleuth
    ];
  };
in
{
  inherit myVimPluginPack;
  vimPlugins = prev.vimPlugins // vimPluginsFromFlake;
}
