{ inputs, makePluginPackages, ... }:
final: prev:
let
  inherit (inputs.nixpkgs) lib;
  inherit (lib) splitString;
  inherit (builtins)
    filter
    readFile
    hasAttr
    replaceStrings
    listToAttrs
    ;

  vimPluginsFromFlake =
    let
      vimPluginRepositoryPrefix = "vim-plugin-";

      vimPluginBuilder =
        repositoryName: repositorySourceCode: date:
        if hasAttr repositoryName prev.vimPlugins then
          prev.vimPlugins.${repositoryName}.overrideAttrs (_old: {
            name = "${repositoryName}-${date}";
            version = date;
            src = repositorySourceCode;
          })
        else
          final.vimUtils.buildVimPlugin {
            pname = repositoryName;
            version = date;
            src = repositorySourceCode;
          };
    in
    makePluginPackages vimPluginRepositoryPrefix vimPluginBuilder;

  myVimPlugins =
    let
      pluginNames = filter (name: name != "") (
        splitString "\n" (readFile "${inputs.self}/dotfiles/neovim/plugin-names.txt")
      );
      replaceDotsWithDashes = replaceStrings [ "." ] [ "-" ];
    in
    final.lib.recurseIntoAttrs (
      listToAttrs (
        map (
          pluginName:
          let
            formattedPluginName = replaceDotsWithDashes pluginName;
            package =
              if hasAttr pluginName final.vimPlugins then
                final.vimPlugins.${pluginName}
              else if hasAttr formattedPluginName final.vimPlugins then
                final.vimPlugins.${formattedPluginName}
              else
                abort "Failed to find vim plugin: ${pluginName}";
          in
          {
            name = pluginName;
            value = package;
          }
        ) pluginNames
      )
    );
in
{
  inherit myVimPlugins;
  vimPlugins = prev.vimPlugins // vimPluginsFromFlake;
}
