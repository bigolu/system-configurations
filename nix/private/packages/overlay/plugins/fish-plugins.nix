{ makePluginPackages, utils, ... }:
_final: prev:
let
  inherit (builtins) hasAttr;
  inherit (utils) toNixpkgsAttr toNixpkgsPname;

  fishPluginRepositoryPrefix = "fish-plugin-";

  fishPluginBuilder =
    repositoryName: repositorySource: version:
    let
      nixpkgsAttrName = toNixpkgsAttr repositoryName;
      fixups = {
        fish-completion-sync = ''
          mkdir conf.d
          mv init.fish conf.d/fish-completion-sync.fish
        '';
      };
    in
    if hasAttr nixpkgsAttrName prev.vimPlugins then
      prev.fishPlugins.${nixpkgsAttrName}.overrideAttrs (_old: {
        inherit version;
        src = repositorySource;
        preInstall = fixups.${repositoryName} or "";
      })
    else
      prev.fishPlugins.buildFishPlugin {
        pname = toNixpkgsPname repositoryName;
        inherit version;
        src = repositorySource;
        preInstall = fixups.${repositoryName} or "";
      };

  fishPluginsFromFlake = makePluginPackages fishPluginRepositoryPrefix fishPluginBuilder;
in
{
  fishPlugins = prev.fishPlugins // fishPluginsFromFlake;
}
