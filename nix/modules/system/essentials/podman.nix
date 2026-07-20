{
  pkgs,
  lib,
  primaryUser,
  ...
}:
let
  inherit (lib) genAttrs genAttrs' nameValuePair;
in
{
  # Required for rootless containers[1].
  #
  # [1]: https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md
  security.wrappers = genAttrs [ "newuidmap" "newgidmap" ] (name: {
    setuid = true;
    owner = "root";
    group = "root";
    source = "${pkgs.shadow}/bin/${name}";
  });

  # Required for rootless containers[1].
  #
  # TODO: `users.users.<username>.autoSubUidGidRange` doesn't work. Probably
  # because system-manager's copy of userborn doesn't have the commit that added
  # subid support[2].
  #
  # [1]: https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md
  # [2]: https://github.com/nikstur/userborn/commit/cd5ea4954f3e24ba33a69e3c5e3c26d128301bbd
  systemd.tmpfiles.settings."10-podman-subids" = genAttrs' [ "subuid" "subgid" ] (
    name:
    nameValuePair "/etc/${name}" {
      "f+" = {
        mode = "0644";
        user = "root";
        group = "root";
        # For these files to be valid, all lines must end in a newline.
        argument = "${primaryUser}:100000:65536\\n";
      };
    }
  );

  home-manager.users.${primaryUser} = {
    fileWrapper.xdg.configFile."containers" = {
      source = "containers";
      # I'm linking recursively because podman makes files in this directory
      recursive = true;
    };

    home.packages = with pkgs; [
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
  };
}
