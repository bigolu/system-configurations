{
  inputs,
  hasGui,
  hostName,
  ...
}:
{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  users = {
    groups.biggs.gid = 1000;
    users.biggs = {
      isNormalUser = true;
      uid = 1000;
      group = "biggs";
      home = "/home/biggs";
      createHome = true;
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "home-manager-backup";
    extraSpecialArgs = { inherit inputs; };
    users.biggs.imports = [ (import ../../home/essentials { inherit hasGui hostName; }) ];
  };
}
