context@{ private, ... }:
let
  inherit (private.utils.homeManager) moduleRoot makeConfiguration;
in
private.pkgs.makePortableShell {
  homeConfig = makeConfiguration {
    configName = "portable";
    pkgOverrides = import ./pkg-overrides.nix context;
    isGui = false;
    isHomeManagerRunningAsASubmodule = true;
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

