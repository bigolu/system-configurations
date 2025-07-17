{
  private,
  lib,
  ...
}:
let
  inherit (builtins) dirOf baseNameOf;
  inherit (lib) pipe recursiveUpdate;
  inherit (private.utils.homeManager) moduleRoot makeConfiguration;
in
recursiveUpdate { activationPackage.meta.platforms = [ "x86_64-linux" ]; } (makeConfiguration {
  configName = pipe __curPos.file [
    dirOf
    baseNameOf
  ];
  modules = [
    "${moduleRoot}/application-development"
    "${moduleRoot}/speakers.nix"
    "${moduleRoot}/comp-1.nix"
  ];
})
