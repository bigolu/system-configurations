{
  pkgs,
  lib,
  utils,
  ...
}:
let
  inherit (pkgs) symlinkJoin runCommand linkFarm;
  inherit (lib) pipe mergeAttrs;
  inherit (utils) removeRecurseIntoAttrs;

  all-treesitter-parsers = symlinkJoin {
    name = "all-treesitter-parsers";
    paths = pkgs.myVimPlugins.nvim-treesitter.withAllGrammars.dependencies;
  };

  vimPack = pipe pkgs.myVimPlugins [
    (mergeAttrs { inherit all-treesitter-parsers; })
    removeRecurseIntoAttrs
    (linkFarm "my-vim-plugins")
    (
      pluginFarm:
      runCommand "my-vim-pack" { } ''
        pack_path="$out/share/nvim/site/pack/bigolu"
        mkdir -p "$pack_path"
        ln --symbolic ${pluginFarm} "$pack_path/start"
      ''
    )
  ];
in
{
  home.packages = [
    pkgs.neovim
    # TODO: Maybe nixpkgs should make share/nvim/site directories for vim plugins,
    # similar to what's done in nixpkgs.fishPlugins.buildFishPlugin. Then I could
    # just list them here instead of having to build a pack.
    vimPack
  ];

  repository.symlink.xdg.configFile."nvim".source = "neovim";
}
