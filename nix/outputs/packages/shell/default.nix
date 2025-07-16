{ private, ... }:
let
  inherit (private.utils.homeManager) moduleRoot makeConfiguration;
in
private.pkgs.makePortableShell {
  homeConfig = makeConfiguration {
    configName = "portable";
    overlay = import ./overlay.nix;
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

