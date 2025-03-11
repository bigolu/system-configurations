{
  lib,
  pkgs,
  repositoryDirectory,
  ...
}:
{
  services.flatpak.packages = [ "org.qbittorrent.qBittorrent" ];

  system = {
    file."/etc/sysctl.d/local.conf".source = "${repositoryDirectory}/dotfiles/sysctl/local.conf";

    activation = {
      # Whenever I resume from suspension on Pop!_OS, I get a black screen
      # and then I have to switch to another tty to reboot. Apparently, the
      # issue is caused by Nvidia. This fix was suggested on the issue
      # tracker[1]. More details on the fix can be found here[2].
      #
      # [1]: https://github.com/pop-os/pop/issues/2605#issuecomment-2526281526
      # [2]: https://wiki.archlinux.org/title/NVIDIA/Tips_and_tricks#Preserve_video_memory_after_suspend
      nvidiaSuspensionFix = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        settings_file='/etc/modprobe.d/bigolu-nvidia-suspension-fix.conf'
        if [[ ! -e $settings_file ]]; then
          setting='options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp'
          echo "$setting" | sudo tee "$settings_file"
          sudo update-initramfs -u -k all
        fi
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
