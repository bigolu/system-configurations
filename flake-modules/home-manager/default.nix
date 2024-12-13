{
  inputs,
  self,
  ...
}:
let
  makeDarwinModules =
    {
      username,
      configName,
      homeDirectory,
      repositoryDirectory,
      modules,
      isGui,
    }:
    let
      extraSpecialArgs = {
        # SYNC: EXTRA-SPECIAL-ARGS
        inherit
          configName
          homeDirectory
          isGui
          repositoryDirectory
          username
          ;
        isHomeManagerRunningAsASubmodule = true;
        flakeInputs = inputs;
        inherit (self.lib) root;
      };
      configuration = {
        home-manager = {
          inherit extraSpecialArgs;
          useGlobalPkgs = true;
          # This makes home-manager install packages to the same path that it
          # normally does, ~/.nix-profile. Though this is the default now, they
          # are considering defaulting to true later so I'm explicitly setting
          # it to false.
          useUserPackages = false;
          users.${username} = {
            imports = modules ++ [ baseModule ];
          };
        };
      };
    in
    [
      inputs.home-manager.darwinModules.home-manager
      configuration
    ];

  makeHomeConfiguration =
    pkgs:
    args@{
      configName,
      modules,
      isGui ? true,
      username ? "biggs",
      isHomeManagerRunningAsASubmodule ? false,
    }:
    let
      homePrefix = if pkgs.stdenv.isLinux then "/home" else "/Users";
      homeDirectory =
        if builtins.hasAttr "homeDirectory" args then args.homeDirectory else "${homePrefix}/${username}";
      repositoryDirectory =
        if builtins.hasAttr "repositoryDirectory" args then
          args.repositoryDirectory
        else
          "${homeDirectory}/code/system-configurations";
      extraSpecialArgs = {
        # SYNC: EXTRA-SPECIAL-ARGS
        inherit
          configName
          homeDirectory
          isGui
          isHomeManagerRunningAsASubmodule
          repositoryDirectory
          username
          ;
        flakeInputs = inputs;
        inherit (self.lib) root;
      };
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      modules = modules ++ [ baseModule ];
      inherit pkgs extraSpecialArgs;
    };

  moduleBaseDirectory = ./modules;

  # This is the module that I always include.
  baseModule = "${moduleBaseDirectory}/profile/base.nix";
in
{
  flake = {
    lib.home = {
      inherit moduleBaseDirectory makeDarwinModules makeHomeConfiguration;
    };
  };

  perSystem =
    {
      pkgs,
      system,
      lib,
      ...
    }:
    let
      configSpecs = [
        {
          system = inputs.flake-utils.lib.system.x86_64-linux;
          configName = "desktop";
          modules = [
            "${moduleBaseDirectory}/profile/application-development.nix"
            "${moduleBaseDirectory}/profile/system-administration.nix"
            "${moduleBaseDirectory}/profile/personal.nix"
          ];
        }
      ];

      configSpecsForCurrentSystem = builtins.filter (config: system == config.system) configSpecs;

      configsForCurrentSystem = builtins.listToAttrs (
        map (config: {
          name = config.configName;
          value = makeHomeConfiguration pkgs (builtins.removeAttrs config [ "system" ]);
        }) configSpecsForCurrentSystem
      );
    in
    lib.optionalAttrs (configsForCurrentSystem != { }) {
      legacyPackages.homeConfigurations = configsForCurrentSystem;
    };
}
