{
  utils,
  lib,
  name,
  ...
}:
let
  inherit (lib) recursiveUpdate;
  inherit (utils.homeManager) moduleRoot makeConfiguration;
in
recursiveUpdate { activationPackage.meta.platforms = [ "x86_64-linux" ]; } (makeConfiguration {
  configName = name;
  modules = [
    (moduleRoot + "/application-development")
    (moduleRoot + "/speakers.nix")
    (moduleRoot + "/comp-1.nix")
  ];
})
