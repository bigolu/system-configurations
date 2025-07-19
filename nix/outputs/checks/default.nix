{
  nixpkgs,
  lib,
  outputs,
  ...
}:
let
  inherit (builtins) getAttr;
  inherit (lib)
    mapAttrs
    mergeAttrsList
    getExe
    ;

  rootlessBundlerCheck =
    let
      rootlessBundlerName = "rootless";
      rootlessBundler = outputs.bundlers.${rootlessBundlerName};
    in
    nixpkgs.runCommand "check-bundler-${rootlessBundlerName}" { } ''
      [[ $(${rootlessBundler nixpkgs.hello}) == $(${getExe nixpkgs.hello}) ]]

      # Nix only considers the command to be successful if something is written
      # to $out.
      echo success > $out
    '';
in
mergeAttrsList [
  { inherit (outputs) packages devShells; }
  { homeConfigurations = mapAttrs (_name: getAttr "activationPackage") outputs.homeConfigurations; }
  { darwinConfigurations = mapAttrs (_name: getAttr "system") outputs.darwinConfigurations; }
  { bundlers.rootless = rootlessBundlerCheck; }
]
