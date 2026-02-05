{
  lib,
  pkgs,
  repositoryDirectory,
  inputs,
  ...
}:
{
  services.flatpak.packages = [ "org.qbittorrent.qBittorrent" ];

  system = {
    file = {
      "/etc/sysctl.d/local.conf".source = "${repositoryDirectory}/dotfiles/sysctl/local.conf";
      "/usr/lib/udev/60-openrgb.rules".source = inputs.openrgb-udev-rules;
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
  };
}
