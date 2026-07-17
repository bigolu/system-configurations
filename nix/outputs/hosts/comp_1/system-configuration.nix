{ myUtils, pins, ... }:
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
    (systemModuleRoot + /application-development.nix)
  ];

  environment.etc = {
    "sysctl.d/local.conf".source = projectRoot + /program-configs/sysctl/local.conf;
    "udev/rules.d/60-openrgb.rules".source = pins.openrgb-udev-rules;
  };

  home-manager.users.biggs = { lib, pkgs, ... }: {
    imports = [ (homeModuleRoot + /application-development) ];

    home.packages = with pkgs; [
      qbittorrent
      openrgb
    ];

    fileWrapper.xdg.configFile = {
      "ghostty/comp-1.ghostty".source = "ghostty/comp-1.ghostty";
    };

    home.activation = {
      # Needs to happen after its config file is installed and I think
      # system-manager installs files in /etc before calling home-manager so
      # `entryAnywhere` should be fine.
      sysctl = lib.hm.dag.entryAnywhere ''
        ${pkgs.moreutils}/bin/chronic /usr/bin/sudo sysctl -p --system
      '';
    };
  };
}
