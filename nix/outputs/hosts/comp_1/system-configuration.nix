{
  lib,
  pkgs,
  myUtils,
  pins,
  ...
}:
let
  inherit (myUtils) projectRoot;
  smartPlugRoot = projectRoot + /program-configs/smart-plug;
  homeModuleRoot = ../../../modules/home;
  systemModuleRoot = ../../../modules/system;
  inherit (pkgs) linkFarm replaceVars;
  inherit (lib) getExe;
in
{
  imports = [
    (import (systemModuleRoot + /essentials.nix) {
      system = "x86_64-linux";
      hasGui = true;
      hostName = "comp_1";
    })
  ];

  systemd = {
    packages = [
      (linkFarm "speaker-units" {
        "lib/systemd/system/start-wake-target.service" = smartPlugRoot + /linux/start-wake-target.service;
        "lib/systemd/system/wake.target" = smartPlugRoot + /linux/wake.target;
        "lib/systemd/system/speakers.service" = replaceVars (smartPlugRoot + /linux/speakers.service) {
          speakerctl = getExe pkgs.speakerctl;
        };
      })
    ];
    services = {
      # SYNC: start-wake-target-wanted-by
      start-wake-target.wantedBy = [ "sleep.target" ];
      # SYNC: speakers-wanted-by
      speakers.wantedBy = [
        "graphical.target"
        "wake.target"
      ];
    };
  };

  environment.etc = {
    "NetworkManager/dispatcher.d/pre-down.d/turn-off-speakers".source =
      smartPlugRoot + /linux/turn-off-speakers.bash;
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

    system.activation = {
      nvidiaSuspensionFix = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        # When I try to suspend, the screen just flashes black and the system
        # doesn't suspend. This fixes it[1].
        #
        # [1]: https://discussion.fedoraproject.org/t/fedora-34-kde-unable-to-suspend-after-nvidia-driver-update/70286/4
        sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service
      '';

      increaseFileWatchLimit = lib.hm.dag.entryAfter [ "installSystemFiles" ] ''
        OLD_PATH="$PATH"
        PATH="$PATH:${pkgs.moreutils}/bin"
        chronic sudo sysctl -p --system
        PATH="$OLD_PATH"
      '';
    };
  };
}
