{ makePluginPackages, ... }:
_final: prev:
let
  fishPluginRepositoryPrefix = "fish-plugin-";
  fishPluginBuilder =
    repositoryName: repositorySourceCode: _ignored:
    repositorySourceCode // { pname = repositoryName; };
  newFishPlugins = makePluginPackages fishPluginRepositoryPrefix fishPluginBuilder;
  fishPlugins = prev.fishPlugins // newFishPlugins;
in
{
  inherit fishPlugins;
}
