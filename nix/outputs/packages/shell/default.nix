context@{ utils, pkgs, ... }:
let
  inherit (utils.homeManager) moduleRoot makeConfiguration;
in
(pkgs.makePortableShell.override { locales = [ "en_US.UTF-8/UTF-8" ]; }) {
  homeConfig = makeConfiguration {
    configName = "portable";
    packageOverrides = import ./package-overrides.nix context;
    hasGui = false;
    modules = [
      (moduleRoot + "/portable.nix")
    ];
  };
  shell = "fish";
  activation = [
    "fzfSetup"
    "batSetup"
  ];
}
