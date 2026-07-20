{
  myUtils,
  pins,
  primaryUser,
  pkgs,
  ...
}:
let
  inherit (myUtils) programConfigRoot;

  homeModuleRoot = ../../../modules/home;
  systemModuleRoot = ../../../modules/system;
in
{
  imports = [
    (import (systemModuleRoot + /essentials) {
      system = "x86_64-linux";
      hasGui = true;
      hostName = "comp_1";
    })
    (systemModuleRoot + /speakers.nix)
    (systemModuleRoot + /podman.nix)
  ];

  environment.etc = {
    "sysctl.d/local.conf".source = programConfigRoot + /sysctl/local.conf;
    "udev/rules.d/60-openrgb.rules".source = pins.openrgb-udev-rules;
    "udev/rules.d/99-keychron-launcher.rules".source =
      programConfigRoot + /keychron-launcher/99-keychron-launcher.rules;
  };

  systemd = {
    services.nvidia-suspension-fix.serviceConfig = {
      Type = "oneshot";
      ExecStart = "/usr/bin/env systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service";
      wantedBy = [ "multi-user.target" ];
    };
    # Sometimes after a system update, the nvidia services get disabled so we
    # have to reenable them.
    paths.nvidia-suspension-fix = {
      pathConfig.PathChanged = "/var/log/dpkg.log";
      wantedBy = [ "multi-user.target" ];
    };
  };

  home-manager.users.${primaryUser} = {
    imports = [
      (homeModuleRoot + /application-development)
      (homeModuleRoot + /seedbox.nix)
    ];

    home.packages = with pkgs; [
      # The keychron configuration tool requires a web API that's only in Chrome.
      google-chrome
    ];

    fileWrapper.xdg.configFile = {
      "ghostty/comp-1.ghostty".source = "ghostty/comp-1.ghostty";
    };
  };
}
