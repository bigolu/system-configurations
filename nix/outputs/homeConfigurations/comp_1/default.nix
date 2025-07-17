{
  private,
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins) dirOf baseNameOf;
  inherit (lib) pipe;
  inherit (private.utils.homeManager) moduleRoot makeConfiguration;
  inherit (pkgs.stdenv) isLinux;
in
if !isLinux then null else
makeConfiguration {
  configName = pipe __curPos.file [ dirOf baseNameOf ];
  modules = [
    "${moduleRoot}/application-development"
    "${moduleRoot}/speakers.nix"
    "${moduleRoot}/comp-1.nix"
  ];
}
