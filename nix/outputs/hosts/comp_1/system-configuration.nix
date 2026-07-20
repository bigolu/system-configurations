{
  myUtils,
  pins,
  primaryUser,
  ...
}:
let
  inherit (myUtils) programConfigRoot;

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
    (systemModuleRoot + /nvidia-suspension-fix.nix)
    (systemModuleRoot + /keychron-launcher.nix)
    (systemModuleRoot + /seedbox.nix)
  ];

  environment.etc = {
    "sysctl.d/local.conf".source = programConfigRoot + /sysctl/local.conf;
    "udev/rules.d/60-openrgb.rules".source = pins.openrgb-udev-rules;
  };

  home-manager.users.${primaryUser} = {
    fileWrapper.xdg.configFile = {
      "ghostty/comp-1.ghostty".source = "ghostty/comp-1.ghostty";
    };
  };
}
