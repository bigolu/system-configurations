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

    system.activation = {
      nvidiaSuspensionFix = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        # When I try to suspend, the screen just flashes black and the system
        # doesn't suspend. This fixes it[1].
        #
        # [1]: https://discussion.fedoraproject.org/t/fedora-34-kde-unable-to-suspend-after-nvidia-driver-update/70286/4
        sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service
      '';

      # Needs to happen after its config file is installed and I think
      # system-manager installs files in /etc before calling home-manager so
      # `entryAnywhere` should be fine.
      increaseFileWatchLimit = lib.hm.dag.entryAnywhere ''
        OLD_PATH="$PATH"
        PATH="$PATH:${pkgs.moreutils}/bin"
        chronic sudo sysctl -p --system
        PATH="$OLD_PATH"
      '';
    };
  };
}
