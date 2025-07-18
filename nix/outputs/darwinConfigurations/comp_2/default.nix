{
  pins,
  utils,
  lib,
  packages,
  ...
}:
let
  inherit (lib) recursiveUpdate;
  inherit (pins.nix-darwin.outputs) darwinSystem;

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
          pins
          utils
          ;
        isHomeManagerRunningAsASubmodule = true;
      };
    in
    [
      pins.home-manager.outputs.nix-darwin
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
    darwinSystem {
      pkgs = packages;
      modules = modules ++ homeManagerSubmodules;
      # SYNC: SPECIAL-ARGS
      specialArgs = {
        inherit
          configName
          username
          homeDirectory
          repositoryDirectory
          pins
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
