{ inputs, makePluginPackages, ... }:
final: prev:
let
  inherit (inputs.nixpkgs) lib;

  vimPluginsFromFlake =
    let
      vimPluginRepositoryPrefix = "vim-plugin-";

      vimPluginBuilder =
        repositoryName: repositorySourceCode: date:
        if builtins.hasAttr repositoryName prev.vimPlugins then
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
      pluginNames = builtins.filter (name: name != "") (
        lib.strings.splitString "\n" (builtins.readFile "${inputs.self}/dotfiles/neovim/plugin-names.txt")
      );
      replaceDotsWithDashes = builtins.replaceStrings [ "." ] [ "-" ];
    in
    final.lib.recurseIntoAttrs (
      builtins.listToAttrs (
        map (
          pluginName:
          let
            formattedPluginName = replaceDotsWithDashes pluginName;
            package =
              if builtins.hasAttr pluginName final.vimPlugins then
                final.vimPlugins.${pluginName}
              else if builtins.hasAttr formattedPluginName final.vimPlugins then
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
