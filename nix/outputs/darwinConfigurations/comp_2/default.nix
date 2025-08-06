{
  inputs,
  utils,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) recursiveUpdate;
  inherit (inputs.nix-darwin.outputs) darwinSystem;

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
      hasGui,
    }:
    [
      inputs.home-manager.outputs.nix-darwin
      {
        home-manager = {
          useGlobalPkgs = true;
          backupFileExtension = "backup";
          users.${username} = {
            imports = modules ++ [ homeManagerCommonModule ];
          };
          # SYNC: SPECIAL-ARGS
          extraSpecialArgs = {
            inherit
              configName
              homeDirectory
              hasGui
              repositoryDirectory
              username
              inputs
              utils
              ;
          };
        };
      }
    ];

  makeDarwinConfiguration =
    {
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
        hasGui = true;
      };
    in
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
          inputs
          utils
          ;
      };
    };
in
recursiveUpdate { system.meta.platforms = [ "x86_64-darwin" ]; } (makeDarwinConfiguration {
  configName = "comp_2";
  modules = [ ./modules/comp-2 ];
  homeModules = [
    "${homeManagerModuleRoot}/application-development"
    "${homeManagerModuleRoot}/speakers.nix"
  ];
})
