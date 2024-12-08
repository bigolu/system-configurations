{
  self,
  inputs,
  ...
}:
let
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
      homeManagerSubmodules = self.lib.home.makeDarwinModules {
        inherit
          username
          configName
          homeDirectory
          repositoryDirectory
          ;
        modules = homeModules;
        isGui = true;
      };
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [ self.lib.overlay ];
      };
    in
    inputs.nix-darwin.lib.darwinSystem {
      inherit pkgs;
      modules = modules ++ homeManagerSubmodules;
      specialArgs = {
        inherit
          configName
          username
          homeDirectory
          repositoryDirectory
          ;
        flakeInputs = inputs;
        inherit (self.lib) root;
      };
    };

  configs = [
    {
      system = inputs.flake-utils.lib.system.x86_64-darwin;
      configName = "bigmac";
      modules = [
        ./modules/profile/base.nix
      ];
      homeModules = [
        "${self.lib.home.moduleBaseDirectory}/profile/system-administration.nix"
        "${self.lib.home.moduleBaseDirectory}/profile/application-development.nix"
        "${self.lib.home.moduleBaseDirectory}/profile/personal.nix"
      ];
    }
  ];

  darwinConfigurationsByName = builtins.listToAttrs (
    map (config: {
      name = config.configName;
      value = makeDarwinConfiguration config;
    }) configs
  );
in
{
  flake = {
    darwinConfigurations = darwinConfigurationsByName;
  };
}
