{
  inputs,
  lib,
  utils,
  withSystem,
  ...
}:
let
  inherit (utils.homeManager) moduleRoot baseModule;
  inherit (builtins)
    attrValues
    mapAttrs
    listToAttrs
    length
    ;
  inherit (inputs.flake-utils.lib) system;
  inherit (inputs.home-manager.lib) homeManagerConfiguration;
  inherit (lib)
    pipe
    nameValuePair
    mergeAttrsList
    ;

  makeOutputsForSpec =
    spec@{
      systems,
      overlay ? null,
      configName,
      modules,
      isGui ? true,
      username ? "biggs",
      isHomeManagerRunningAsASubmodule ? false,
    }:
    let
      getOutputNameForSystem =
        system: if (length systems) == 1 then configName else "${configName}-${system}";

      makeConfigForSystem =
        system:
        withSystem system (
          { pkgs, ... }:
          let
            inherit (pkgs.stdenv) isLinux;

            homePrefix = if isLinux then "/home" else "/Users";
            homeDirectory = spec.homeDirectory or "${homePrefix}/${username}";
            repositoryDirectory = spec.repositoryDirectory or "${homeDirectory}/code/system-configurations";
            # SYNC: SPECIAL-ARGS
            extraSpecialArgs = {
              inherit
                configName
                homeDirectory
                isGui
                isHomeManagerRunningAsASubmodule
                repositoryDirectory
                username
                utils
                inputs
                ;
            };
          in
          homeManagerConfiguration {
            modules = modules ++ [ baseModule ];
            inherit extraSpecialArgs;
            pkgs = if overlay == null then pkgs else pkgs.extend overlay;
          }
        );
    in
    pipe systems [
      (map (system: nameValuePair (getOutputNameForSystem system) (makeConfigForSystem system)))
      listToAttrs
    ];

  makeOutputs = configSpecs: {
    # The 'flake' and 'homeConfigurations' keys need to be static to avoid infinite
    # recursion
    flake.homeConfigurations = pipe configSpecs [
      (mapAttrs (configName: spec: spec // { inherit configName; }))
      attrValues
      (map makeOutputsForSpec)
      mergeAttrsList
    ];
  };
in
makeOutputs {
  linux = {
    systems = with system; [ x86_64-linux ];
    modules = [
      "${moduleRoot}/profile/application-development"
      "${moduleRoot}/profile/speakers.nix"
      "${moduleRoot}/profile/linux.nix"
    ];
  };

  portable-home = {
    systems = with system; [
      x86_64-linux
      x86_64-darwin
    ];
    modules = [
      "${moduleRoot}/profile/portable.nix"
    ];
    overlay = import ./overlays/portable.nix;
    isGui = false;
    isHomeManagerRunningAsASubmodule = true;
  };
}
