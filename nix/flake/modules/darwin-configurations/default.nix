{
  inputs,
  utils,
  withSystem,
  lib,
  ...
}:
let
  inherit (builtins) mapAttrs;
  inherit (lib) pipe mergeAttrs;
  inherit (inputs.flake-utils.lib) system;
  inherit (inputs.nix-darwin.lib) darwinSystem;

  homeManagerUtils = utils.homeManager;
  homeManagerCommonModule = homeManagerUtils.commonModule;
  homeManagerModuleRoot = homeManagerUtils.moduleRoot;

  makeHomeManagerDarwinModules =
    {
      username,
      configName,
      homeDirectory,
      repositoryDirectory,
      modules,
      isGui,
    }:
    let
      # SYNC: SPECIAL-ARGS
      extraSpecialArgs = {
        inherit
          configName
          homeDirectory
          isGui
          repositoryDirectory
          username
          utils
          inputs
          ;
        isHomeManagerRunningAsASubmodule = true;
      };
    in
    [
      inputs.home-manager.darwinModules.home-manager
      {
        home-manager = {
          inherit extraSpecialArgs;
          useGlobalPkgs = true;
          backupFileExtension = "backup";
          users.${username} = {
            imports = modules ++ [ homeManagerCommonModule ];
          };
        };
      }
    ];

  makeDarwinConfiguration =
    {
      system,
      configName,
      modules,
      homeModules,
      username ? "biggs",
      homeDirectory ? "/Users/${username}",
      repositoryDirectory ? "${homeDirectory}/code/system-configurations",
    }:
    let
      homeManagerSubmodules = makeHomeManagerDarwinModules {
        inherit
          username
          configName
          homeDirectory
          repositoryDirectory
          ;
        modules = homeModules;
        isGui = true;
      };
    in
    withSystem system (
      { pkgs, ... }:
      darwinSystem {
        inherit pkgs;
        modules = modules ++ homeManagerSubmodules;
        # SYNC: SPECIAL-ARGS
        specialArgs = {
          inherit
            configName
            username
            homeDirectory
            repositoryDirectory
            utils
            inputs
            ;
        };
      }
    );

  makeOutputs = configSpecs: {
    # The 'flake' and 'darwinConfigurations' keys need to be static to avoid infinite
    # recursion
    flake.darwinConfigurations = pipe configSpecs [
      (mapAttrs (configName: mergeAttrs { inherit configName; }))
      (mapAttrs (_configName: makeDarwinConfiguration))
    ];
  };
in
makeOutputs {
  comp_2 = {
    system = system.x86_64-darwin;
    modules = [ ./modules/comp-2 ];
    homeModules = [
      "${homeManagerModuleRoot}/application-development"
      "${homeManagerModuleRoot}/speakers.nix"
    ];
  };
}
