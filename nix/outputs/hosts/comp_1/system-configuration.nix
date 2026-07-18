{
  myUtils,
  pins,
  primaryUser,
  ...
}:
let
  inherit (myUtils) projectRoot;
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
    "sysctl.d/local.conf".source = projectRoot + /program-configs/sysctl/local.conf;
    "udev/rules.d/60-openrgb.rules".source = pins.openrgb-udev-rules;
    "udev/rules.d/99-keychron-launcher.rules".source =
      projectRoot + /program-configs/keychron-launcher/99-keychron-launcher.rules;
  };

  home-manager.users.${primaryUser} = { pkgs, ... }: {
    imports = [ (homeModuleRoot + /application-development) ];

    home.packages = with pkgs; [
      qbittorrent
      openrgb
      # The keychron configuration tool requires a web API that's only in Chrome.
      google-chrome
    ];

    fileWrapper.xdg.configFile = {
      "ghostty/comp-1.ghostty".source = "ghostty/comp-1.ghostty";
    };
  };
}
