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
let
  nixRoot = ../../../../..;
in
{
  imports = [
    ./non-nixos-gpu-setup.nix
    ./sudo.nix
  ];

  _module.args = {
    pkgs = lib.mkForce (import (nixRoot + /packages.nix) { inherit system; });
    myUtils = import (nixRoot + /utils.nix);
    pins = import (nixRoot + /pins) pkgs;
    inherit hasGui;
    inherit hostName;
  };

  system-manager.allowAnyDistro = true;
  nixpkgs.hostPlatform = system;
  users.users.${primaryUser}.isNormalUser = true;

  home-manager.users.${primaryUser} =
    { lib, ... }:
    let
      inherit (lib) hm;
      utils = import (nixRoot + /utils.nix);
    in
    {
      imports = [ (utils.modules.home.essentials { inherit hasGui hostName; }) ];

      home = {
        # TODO: I'm only doing this because Pop!_OS doesn't come with it by
        # default, but I think it should.
        packages = [ pkgs.wl-clipboard ];

        # These services need to be reloaded after their config files are
        # installed and I think system-manager links files in /etc before
        # calling home-manager so `entryAnywhere` should be fine.
        #
        # TODO: I'd rather set `restartTriggers` on the `systemd-{udevd,sysctl}`
        # services, but my distro makes those services and if I set
        # <service>.`restartTriggers`, system-manager replaces the entire
        # service definition.
        activation.restartSystemServices = hm.dag.entryAnywhere ''
          /usr/bin/sudo /usr/bin/udevadm control --reload-rules
          /usr/bin/sudo /usr/bin/udevadm trigger

          ${pkgs.moreutils}/bin/chronic /usr/bin/sudo /usr/sbin/sysctl -p --system
        '';
      };
    };
}
