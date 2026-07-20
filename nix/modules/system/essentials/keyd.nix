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

  home-manager.users.${primaryUser} = {
    fileWrapper.xdg.configFile."keyd/app.conf".source = "keyd/app.conf";
    home.packages = with pkgs; [ keyd ];

    systemd.user.services.keyd-application-mapper = {
      Unit = {
        Description = "Application-Specific mappings for keyd";
        After = "multi-user.target";
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.keyd}/bin/keyd-application-mapper -d";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
