{
  pkgs,
  myUtils,
  config,
  primaryUser,
  ...
}:
let
  inherit (myUtils) programConfigRoot;
in
{
  environment.etc."keyd/default.conf".source = programConfigRoot + /keyd/default.conf;

  users = {
    groups.keyd = { };
    users.${primaryUser}.extraGroups = [ "keyd" ];
  };

  systemd = {
    packages = [ pkgs.keyd ];
    services.keyd = {
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ config.environment.etc."keyd/default.conf".source ];
    };
  };
}
