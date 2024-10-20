{
  self,
  inputs,
  ...
}:
let
  makeDarwinConfigurationByHostName =
    {
      system,
      hostName,
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
          hostName
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
      darwinConfiguration = inputs.nix-darwin.lib.darwinSystem {
        inherit pkgs;
        modules = modules ++ homeManagerSubmodules;
        specialArgs = {
          inherit
            hostName
            username
            homeDirectory
            repositoryDirectory
            ;
          flakeInputs = inputs;
          inherit (self.lib) root;
        };
      };
    in
    {
      ${hostName} = darwinConfiguration;
    };

  hosts = [
    {
      system = inputs.flake-utils.lib.system.x86_64-darwin;
      hostName = "bigmac";
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
  darwinConfigurationsByHostName = map makeDarwinConfigurationByHostName hosts;
in
{
  flake = {
    darwinConfigurations = self.lib.recursiveMerge darwinConfigurationsByHostName;
  };
}
