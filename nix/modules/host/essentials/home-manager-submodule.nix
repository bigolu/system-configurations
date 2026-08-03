{
  _class,
  inputs,
  lib,
  ...
}:
let
  inherit (lib) genAttrs const;
in
(genAttrs [ "" "darwin" ] (const {
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
})).${toString _class}
