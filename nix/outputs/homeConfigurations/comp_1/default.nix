{
  private,
  lib,
  ...
}:
let
  inherit (lib) recursiveUpdate;
  inherit (private.utils.homeManager) moduleRoot makeConfiguration;
in
recursiveUpdate { activationPackage.meta.platforms = [ "x86_64-linux" ]; } (makeConfiguration {
  configName = "comp_1";
  modules = [
    "${moduleRoot}/application-development"
    "${moduleRoot}/speakers.nix"
    "${moduleRoot}/comp-1.nix"
  ];
})
