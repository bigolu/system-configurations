{
  self,
  inputs,
  ...
}:
{
  perSystem =
    {
      pkgs,
      system,
      lib,
      ...
    }:
    let
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

      configSpecs = [
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

      configSpecsForCurrentSystem = builtins.filter (config: system == config.system) configSpecs;

      configsForCurrentSystem = builtins.listToAttrs (
        map (config: {
          name = config.configName;
          value = makeDarwinConfiguration (builtins.removeAttrs config [ "system" ]);
        }) configSpecsForCurrentSystem
      );
    in
    lib.optionalAttrs (configsForCurrentSystem != { }) {
      legacyPackages.darwinConfigurations = configsForCurrentSystem;
    };
}
