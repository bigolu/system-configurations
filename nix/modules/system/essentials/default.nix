{
  system,
  hostName,
  hasGui,
}:
{
  pkgs,
  lib,
  primaryUser,
  ...
}:
{
  imports = [
    ./home-manager.nix
    ./keyd.nix
    ./login-shell.nix
    ./non-nixos-gpu-setup.nix
    ./sudo.nix
    ./podman.nix
  ];

  _module.args = {
    pkgs = lib.mkForce (import ../../../packages.nix { inherit system; });
    myUtils = import ../../../utils.nix;
    pins = import ../../../pins pkgs;
    inherit hasGui;
    inherit hostName;
    primaryUser = "biggs";
  };

  system-manager.allowAnyDistro = true;
  nixpkgs.hostPlatform = system;
  users.users.${primaryUser}.isNormalUser = true;

  home-manager.users.${primaryUser} =
    { lib, ... }:
    let
      inherit (lib) hm;
    in
    {
      imports = [
        (import ../../home/essentials { inherit hasGui hostName; })
        ../../home/application-development.nix
      ];

      home = {
        # TODO: I'm only doing this because Pop!_OS doesn't come with it by
        # default, but I think it should.
        packages = [ pkgs.wl-clipboard ];

        activation = {
          # These tools need to be reloaded after their config files are installed
          # and I think system-manager links files in /etc before calling
          # home-manager so `entryAnywhere` should be fine.
          #
          # TODO: I'd rather set `restartTriggers` on the `systemd-{udevd,sysctl}`
          # service, but my distro makes those services and if I set
          # <service>.`restartTriggers`, system-manager replaces the entire
          # service definition.
          udev = hm.dag.entryAnywhere ''
            /usr/bin/sudo /usr/bin/udevadm control --reload-rules
            /usr/bin/sudo /usr/bin/udevadm trigger
          '';
          sysctl = lib.hm.dag.entryAnywhere ''
            ${pkgs.moreutils}/bin/chronic /usr/bin/sudo /usr/sbin/sysctl -p --system
          '';
        };
      };
    };
}
