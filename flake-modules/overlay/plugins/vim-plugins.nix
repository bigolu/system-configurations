{ inputs, makePluginPackages, ... }:
final: prev:
let
  inherit (final) lib;

  vimPluginRepositoryPrefix = "vim-plugin-";

  vimPluginBuilder =
    repositoryName: repositorySourceCode: date:
    if builtins.hasAttr repositoryName prev.vimPlugins then
      (builtins.getAttr repositoryName prev.vimPlugins).overrideAttrs (_old: {
        name = "${repositoryName}-${date}";
        version = date;
        src = repositorySourceCode;
      })
    else
      prev.vimUtils.buildVimPlugin {
        pname = repositoryName;
        version = date;
        src = repositorySourceCode;
      };

  newVimPlugins = makePluginPackages vimPluginRepositoryPrefix vimPluginBuilder;

  treesitter-parsers = final.symlinkJoin {
    name = "treesitter-parsers";
    paths = newVimPlugins.nvim-treesitter.withAllGrammars.dependencies;
  };

  vimPlugins =
    prev.vimPlugins
    // newVimPlugins
    // {
      inherit treesitter-parsers;
      # remove treesitter parser plugins because they were ending up in my
      # 'plugged' directory
      nvim-treesitter = newVimPlugins.nvim-treesitter.withPlugins (_: [ ]);
    };

  myVimPlugins =
    let
      pluginNames = builtins.filter (name: name != "") (
        lib.strings.splitString "\n" (builtins.readFile "${inputs.self}/dotfiles/neovim/plugin-names.txt")
      );
      replaceDotsWithDashes = builtins.replaceStrings [ "." ] [ "-" ];
    in
    builtins.listToAttrs (
      map (
        pluginName:
        let
          getPackageForPlugin = builtins.getAttr pluginName;
          formattedPluginName = replaceDotsWithDashes pluginName;
          package =
            if builtins.hasAttr pluginName final.vimPlugins then
              getPackageForPlugin final.vimPlugins
            else if builtins.hasAttr formattedPluginName final.vimPlugins then
              (builtins.getAttr "overrideAttrs" (builtins.getAttr formattedPluginName final.vimPlugins)) (_old: {
                pname = pluginName;
              })
            else
              abort "Failed to find vim plugin: ${pluginName}";
        in
        {
          name = pluginName;
          value = package;
        }
      ) pluginNames
    );
in
{
  inherit vimPlugins myVimPlugins;
}
