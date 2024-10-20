{ makePluginPackages, ... }:
_final: prev:
let
  fishPluginRepositoryPrefix = "fish-plugin-";
  fishPluginBuilder =
    _ignored: repositorySourceCode: _ignored:
    repositorySourceCode;
  newFishPlugins = makePluginPackages fishPluginRepositoryPrefix fishPluginBuilder;
  fishPlugins = prev.fishPlugins // newFishPlugins;
in
{
  inherit fishPlugins;
}
