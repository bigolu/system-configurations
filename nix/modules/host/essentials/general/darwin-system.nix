{
  pkgs,
  lib,
  primaryUser,
  hostName,
  ...
}:
let
  inherit (lib) optionals;
in
{
  _module.args.primaryUser = "biggs";

  home-manager.users.${primaryUser} = { config, ... }: {
    xdg.stateFile."bigolu/system-config-name".text = hostName;
    # For my shebang scripts
    home.packages = optionals config.fileWrapper.settings.editableInstall [ pkgs.bash ];
  };
}
