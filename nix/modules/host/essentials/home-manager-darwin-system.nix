type: { inputs, ... }: {
  imports = [
    inputs.home-manager."${if type == "system" then "nixos" else "darwin"}Modules".home-manager
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "home-manager-backup";
    extraSpecialArgs = { inherit inputs; };
  };
}
