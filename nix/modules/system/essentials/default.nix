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
    ./run-as-admin.nix
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
      home.activation = {
        # These tools need to be reloaded after their config files are installed
        # and I think system-manager links files in /etc before calling
        # home-manager so `entryAnywhere` should be fine.
        #
        # TODO: I'd rather set `restartTriggers` on the `systemd-{udevd,sysctl}`
        # service, but my distro makes those services and if I set
        # <service>.`restartTriggers`, system-manager replaces the entire
        # service definition.
        udev = hm.dag.entryAnywhere ''
          /usr/bin/sudo udevadm control --reload-rules
          /usr/bin/sudo udevadm trigger
        '';
        sysctl = lib.hm.dag.entryAnywhere ''
          /usr/bin/sudo sysctl -p --system
        '';
      };
    };
}
