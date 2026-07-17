{
  inputs,
  hasGui,
  hostName,
  ...
}:
{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "home-manager-backup";
    extraSpecialArgs = { inherit inputs; };
    users.biggs.imports = [ (import ../../home/essentials { inherit hasGui hostName; }) ];
  };
}
