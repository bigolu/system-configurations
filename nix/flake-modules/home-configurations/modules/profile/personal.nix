{ lib, ... }:
let
  inherit (lib) hm;
in
{
  imports = [
    ../speakers.nix
  ];

  # Whenever I resume from suspension on Pop!_OS, I get a black screen and then I
  # have to switch to another tty to reboot. Apparently, the issue is caused by
  # Nvidia. This fix was suggested on the issue tracker[1]. More details on the fix
  # can be found here[2].
  #
  # [1]: https://github.com/pop-os/pop/issues/2605#issuecomment-2526281526
  # [2]: https://wiki.archlinux.org/title/NVIDIA/Tips_and_tricks#Preserve_video_memory_after_suspend
  home.activation.nvidiaSuspensionFix = hm.dag.entryAfter [ "writeBoundary" ] ''
    # Add /usr/bin so scripts can access system programs like sudo/apt
    # Apparently macOS hasn't merged /bin and /usr/bin so add /bin too.
    PATH="$PATH:/usr/bin:/bin"

    settings_file='/etc/modprobe.d/bigolu-nvidia-suspension-fix.conf'
    if [[ ! -e $settings_file ]]; then
      setting='options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp'
      echo "$setting" | sudo tee "$settings_file"
      sudo update-initramfs -u -k all
    fi
  '';
}
