{
  inputs,
  self,
  ...
}:
let
  moduleBaseDirectory = ./modules;

  # This is the module that I always include.
  baseModule = "${moduleBaseDirectory}/profile/base.nix";

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
          username
          homeDirectory
          repositoryDirectory
          isGui
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
    args@{
      system,
      configName,
      modules,
      isGui ? true,
      username ? "biggs",
      overlays ? [ ],
      isHomeManagerRunningAsASubmodule ? false,
    }:
    let
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [ self.lib.overlay ] ++ overlays;
      };
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
          isGui
          username
          homeDirectory
          repositoryDirectory
          isHomeManagerRunningAsASubmodule
          ;
        flakeInputs = inputs;
        inherit (self.lib) root;
      };
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      modules = modules ++ [ baseModule ];
      inherit pkgs extraSpecialArgs;
    };

  configs = [
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

  homeConfigurationsByName = builtins.listToAttrs (
    map (config: {
      name = config.configName;
      value = makeHomeConfiguration config;
    }) configs
  );
in
{
  flake = {
    lib.home = {
      inherit moduleBaseDirectory makeDarwinModules makeHomeConfiguration;
    };

    homeConfigurations = homeConfigurationsByName;
  };
}
