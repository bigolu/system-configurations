moduleType:
{
  inputs,
  primaryUser,
  hostName,
  ...
}:
{
  imports = [ inputs.home-manager."${moduleType}Modules".home-manager ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "home-manager-backup";
    extraSpecialArgs = { inherit inputs; };

    users.${primaryUser} = { config, ... }: {
      xdg.stateFile."bigolu/system-config-name".text =
        if config.submoduleSupport.enable then hostName else "${config.home.username}@${hostName}";
    };
  };
}
