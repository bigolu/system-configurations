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
      extraSpecialArgs = { inherit inputs; };
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
