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
      hostName,
      homeDirectory,
      repositoryDirectory,
      modules,
      isGui,
    }:
    let
      extraSpecialArgs = {
        # SYNC: EXTRA-SPECIAL-ARGS
        inherit
          hostName
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

  makeHomeConfigurationByHostName =
    args@{
      system,
      hostName,
      modules,
      isGui ? true,
      username ? "biggs",
      overlays ? [ ],
    }:
    let
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ] ++ overlays;
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
          hostName
          isGui
          username
          homeDirectory
          repositoryDirectory
          ;
        isHomeManagerRunningAsASubmodule = false;
        flakeInputs = inputs;
        inherit (self.lib) root;
      };
    in
    {
      ${hostName} = inputs.home-manager.lib.homeManagerConfiguration {
        modules = modules ++ [ baseModule ];
        inherit pkgs extraSpecialArgs;
      };
    };

  hosts = [
    {
      system = inputs.flake-utils.lib.system.x86_64-linux;
      hostName = "desktop";
      modules = [
        "${moduleBaseDirectory}/profile/application-development.nix"
        "${moduleBaseDirectory}/profile/system-administration.nix"
        "${moduleBaseDirectory}/profile/personal.nix"
      ];
    }
  ];
  homeConfigurationsByHostName = map makeHomeConfigurationByHostName hosts;
in
{
  flake = {
    lib.home = {
      inherit moduleBaseDirectory makeDarwinModules makeHomeConfigurationByHostName;
    };

    homeConfigurations = self.lib.recursiveMerge homeConfigurationsByHostName;
  };
}
