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
  homeManagerBaseModule = utils.homeManager.baseModule;
  homeManagerModuleRoot = utils.homeManager.moduleRoot;

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
          # This makes home-manager install packages to the same path that it
          # normally does, ~/.nix-profile. Though this is the default now, they
          # are considering defaulting to true later so I'm explicitly setting
          # it to false.
          useUserPackages = false;
          users.${username} = {
            imports = modules ++ [ homeManagerBaseModule ];
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
      inputs.nix-darwin.lib.darwinSystem {
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
  bigmac = {
    system = inputs.flake-utils.lib.system.x86_64-darwin;
    modules = [
      ./modules/profile/base.nix
    ];
    homeModules = [
      "${homeManagerModuleRoot}/profile/system-administration.nix"
      "${homeManagerModuleRoot}/profile/application-development.nix"
      "${homeManagerModuleRoot}/profile/personal.nix"
    ];
  };
}
