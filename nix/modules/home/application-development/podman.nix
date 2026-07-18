{ pkgs, lib, ... }:
let
  inherit (lib) optional;
  inherit (pkgs.stdenv.hostPlatform) isLinux;
in
{
  fileWrapper.xdg.configFile."containers" = {
    source = "containers";
    # I'm linking recursively because podman makes files in this directory
    recursive = true;
  };

  home.packages = optional isLinux pkgs.podman-desktop;

  # The Docker cli relies on a daemon to make containers, but Podman doesn't use
  # one. For compatibility, Podman provides a daemon as a socket-activated
  # systemd service.
  systemd.user = {
    packages = [ pkgs.podman ];
    # Unlike system-manager, units defined directly in home-manager seem to
    # replace the ones from packages, rather than merge with them. This means we
    # need to copy the whole socket defintion, not just `WantedBy`.
    sockets.podman = {
      Socket = {
        ListenStream = "%t/podman/podman.sock";
        SocketMode = "0660";
      };
      Install.WantedBy = [ "sockets.target" ];
    };
  };
}
