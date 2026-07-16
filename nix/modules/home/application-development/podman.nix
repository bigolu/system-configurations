{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (lib) optionalAttrs optionals hm;
  inherit (pkgs.stdenv.hostPlatform) isLinux;
in
{
  fileWrapper.xdg.configFile = {
    "containers" = {
      source = "containers";
      # I'm linking recursively because podman makes files in this directory
      recursive = true;
    };
  };

  home.packages =
    with pkgs;
    optionals isLinux [
      podman
      podman-compose
      podman-desktop
    ];

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

  system.activation = optionalAttrs isLinux {
    # For rootless containers, my user needs to be able to create {u,g}id maps in
    # its child processes[1].
    #
    # [1]: https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md
    configureSubIds = hm.dag.entryAfter [ "writeBoundary" ] ''
      sudo "${pkgs.shadow}/bin/usermod" \
        --add-subuids 100000-165535 \
        --add-subgids 100000-165535 \
        ${config.home.username}

      # The programs below need setuid
      for file in ${pkgs.shadow}/bin/new[ug]idmap; do
        basename="''${file##*/}"
        destination=/usr/local/bin/"$basename"
        sudo cp "$file" "$destination"

        # This is the user, group, and mode that was set on the newuidmap installed
        # by APT.
        sudo chown root:root "$destination"
        sudo chmod 'u+s,g-s,u+rwx,g+rx,o+rx' "$destination"
      done
    '';
  };
}
