context@{ utils, pkgs, ... }:
let
  inherit (utils.homeManager) moduleRoot makeConfiguration;
in
(pkgs.makePortableShell.override {
  # The full set of locales is pretty big (~220MB) so I'll only include the one that
  # will be used.
  locales = [ "en_US.UTF-8/UTF-8" ];
})
  {
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
