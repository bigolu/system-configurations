{
  pkgs,
  lib,
  username,
  ...
}:
let
  inherit (lib)
    optionalAttrs
    optionals
    hm
    makeBinPath
    ;
  inherit (pkgs.stdenv) isLinux isDarwin;
in
{
  repository.xdg.configFile = {
    "containers/policy.json".source = "containers/policy.json";
    "containers/registries.conf".source = "containers/registries.conf";
  };

  home.packages =
    with pkgs;
    optionals isLinux [
      podman
      podman-compose
    ];

  services.flatpak = optionalAttrs isLinux {
    packages = [
      "io.podman_desktop.PodmanDesktop"
    ];
    # The Podman Desktop flatpak is configured to use X11, but I force all electron
    # apps to use Wayland by setting the environment variable
    # `ELECTRON_OZONE_PLATFORM_HINT=auto`. These additional permissions are required
    # for Wayland support.
    overrides."io.podman_desktop.PodmanDesktop".Context.sockets = [
      "system-bus"
      "wayland"
    ];
  };

  home.activation =
    optionalAttrs isDarwin {
      createPodmanMachine =
        let
          dependencies = makeBinPath (
            with pkgs;
            [
              podman
              jq
            ]
          );
        in
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          OLD_PATH="$PATH"
          # /usr/bin is required since podman needs `ssh-keygen`
          PATH="${dependencies}:$PATH:/usr/bin"

          machine_count=$(podman machine list --format json | jq length)
          if (($machine_count == 0)); then
            podman machine init --cpus 6 --memory 7629 --disk-size 55 --rootful
          fi

          PATH="$OLD_PATH"
        '';
    }
    // optionalAttrs isLinux {
      # The Docker cli relies on a daemon to make containers, but Podman doesn't use
      # one. For compatibility, Podman provides a daemon as a socket-activated
      # systemd service.
      #
      # TODO: Home Manager should allow you to pass systemd files to install instead
      # of only taking nix attribute sets. This way I could just pass these files in.
      installPodmanDockerCompat = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        OLD_PATH="$PATH"
        PATH="$PATH:${pkgs.moreutils}/bin"

        # For `systemctl --user`
        export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

        function set_up_unit {
          unit_name="$1"
          unit_base_name="''${unit_name##*/}"

          if systemctl --user list-unit-files "$unit_base_name" 1>/dev/null 2>&1; then
            # This will unlink it
            chronic systemctl --user disable "$unit_base_name"
          fi
          chronic systemctl --user link "$unit_name"
          chronic systemctl --user enable "$unit_base_name"

          # - If I don't this then `systemctl status <name>` shows that any timer
          #   set up here failed because it 'vanished'
          # - socket units need to be started
          extension="''${unit_base_name##*.}"
          if [[ $extension == 'timer' || $extension == 'socket' ]]; then
            chronic systemctl --user start "$unit_base_name"
          fi
        }

        for unit in ${pkgs.podman}/lib/systemd/user/podman.{service,socket}; do
          set_up_unit "$unit"
        done

        PATH="$OLD_PATH"
      '';
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
        ${username}

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
