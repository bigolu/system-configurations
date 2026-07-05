{
  lib,
  pkgs,
  repositoryDirectory,
  pins,
  utils,
  ...
}:
let
  inherit (pkgs) speakerctl replaceVars writeTextDir;
  inherit (lib) getExe readFile;
  inherit (utils) projectRoot;

  smartPlugRoot = "${repositoryDirectory}/program-configs/smart-plug";

  speakerService =
    let
      speakerServiceName = "speakers.service";
      speakerServiceTemplate = projectRoot + /program-configs/smart-plug/linux/speakers.service;

      processedTemplate = replaceVars speakerServiceTemplate { speakerctl = getExe speakerctl; };
    in
    # This way the basename of the file will be `speakerServiceName` which is
    # necessary for `config.system.systemd.units`.
    "${writeTextDir speakerServiceName (readFile processedTemplate)}/${speakerServiceName}";
in
{
  services.flatpak.packages = [ "org.qbittorrent.qBittorrent" ];

  system = {
    file = {
      "/etc/sysctl.d/local.conf".source = "${repositoryDirectory}/program-configs/sysctl/local.conf";
      "/usr/lib/udev/60-openrgb.rules".source = pins.openrgb-udev-rules;
    };

    activation = {
      nvidiaSuspensionFix = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        # When I try to suspend, the screen just flashes black and the system
        # doesn't suspend. This fixes it [1].
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

    systemd.units = [
      "${smartPlugRoot}/linux/start-wake-target.service"
      "${smartPlugRoot}/linux/wake.target"
      "${speakerService}"
    ];
    file."/etc/NetworkManager/dispatcher.d/pre-down.d/turn-off-speakers".source =
      "${smartPlugRoot}/linux/turn-off-speakers.bash";
  };
}
