context@{ utils, pkgs, ... }:
let
  inherit (utils.homeManager) moduleRoot makeConfiguration;
in
pkgs.makePortableShell {
  homeConfig = makeConfiguration {
    configName = "portable";
    packageOverrides = import ./package-overrides.nix context;
    hasGui = false;
    modules = [
      "${moduleRoot}/portable.nix"
    ];
  };
  shell = "fish";
  activation = [
    "fzfSetup"
    "batSetup"
  ];
}
