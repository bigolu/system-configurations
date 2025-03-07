{
  makePluginPackages,
  utils,
  ...
}:
final: prev:
let
  inherit (builtins)
    hasAttr
    ;
  inherit (utils) toNixpkgsAttr toNixpkgsPname;

  vimPluginsFromFlake =
    let
      vimPluginRepositoryPrefix = "vim-plugin-";

      vimPluginBuilder =
        repositoryName: repositorySourceCode: date:
        let
          nixpkgsAttrName = toNixpkgsAttr repositoryName;
        in
        if hasAttr nixpkgsAttrName prev.vimPlugins then
          prev.vimPlugins.${nixpkgsAttrName}.overrideAttrs (_old: {
            version = date;
            src = repositorySourceCode;
          })
        else
          final.vimUtils.buildVimPlugin {
            pname = toNixpkgsPname repositoryName;
            version = date;
            src = repositorySourceCode;
          };
    in
    makePluginPackages vimPluginRepositoryPrefix vimPluginBuilder;

  myVimPluginPack = final.vimUtils.packDir {
    bigolu.start = with final.vimPlugins; [
      # TODO: Per nixpkgs' package naming rules, they should lowercase this:
      # https://github.com/NixOS/nixpkgs/blob/master/pkgs/README.md#package-naming
      Navigator-nvim
      camelcasemotion
      dial-nvim
      direnv-vim
      fidget-nvim
      lazy-lsp-nvim
      mini-nvim
      multicursor-nvim
      nvim-autopairs
      nvim-lightbulb
      nvim-lspconfig
      nvim-treesitter-context
      nvim-treesitter-endwise
      nvim-treesitter-textobjects
      nvim-treesitter.withAllGrammars
      nvim-ts-autotag
      splitjoin-vim
      treesj
      # Commands/mappings for working with variants of words. In particular I use its
      # 'S' command for performing substitutions. It has more features than vim's
      # built-in :substitution
      #
      # TODO: issue for `inccommand` support: https://github.com/tpope/vim-abolish/issues/107
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
