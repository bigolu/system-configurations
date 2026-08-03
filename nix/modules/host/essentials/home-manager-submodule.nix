{ _class, inputs, ... }:
let
  darwinAndSystem = {
    imports = [
      inputs.home-manager."${
        {
          "" = "nixos";
          darwin = "darwin";
        }
        .${toString _class}
      }Modules".home-manager
    ];

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "home-manager-backup";
      overwriteBackup = true;
      extraSpecialArgs = { inherit inputs; };
      sharedModules = [ ./. ];
    };
  };
in
{
  "" = {
    imports = [ darwinAndSystem ];
  };

  darwin = {
    imports = [ darwinAndSystem ];
  };
}
.${toString _class}
