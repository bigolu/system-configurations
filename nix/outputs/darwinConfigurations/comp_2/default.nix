{
  pins,
  utils,
  private,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) pipe;
  inherit (pins.nix-darwin.outputs) darwinSystem;
  inherit (pkgs.stdenv) isDarwin;

  homeManagerUtils = private.utils.homeManager;
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
          ;
        isHomeManagerRunningAsASubmodule = true;
        utils = utils // private.utils;
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
      pkgs = private.pkgs;
      modules = modules ++ homeManagerSubmodules;
      # SYNC: SPECIAL-ARGS
      specialArgs = {
        utils = utils // private.utils;
        inherit
          configName
          username
          homeDirectory
          repositoryDirectory
          pins
          ;
      };
    };
in
if !isDarwin then null else
makeDarwinConfiguration {
  configName = pipe __curPos.file [ dirOf baseNameOf ];
  modules = [ ./modules/comp-2 ];
  homeModules = [
    "${homeManagerModuleRoot}/application-development"
    "${homeManagerModuleRoot}/speakers.nix"
  ];
}
