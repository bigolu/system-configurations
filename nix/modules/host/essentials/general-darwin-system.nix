{
  pkgs,
  lib,
  config,
  primaryUser,
  ...
}:
let
  inherit (lib) optionals;
in
{
  _module.args.primaryUser = "biggs";

  # For my shebang scripts
  home-manager.users.${primaryUser}.home.packages =
    optionals config.home-manager.users.${primaryUser}.fileWrapper.settings.editableInstall
      [ pkgs.bash ];
};
