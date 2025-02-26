# TODO: See if any of this should be upstreamed.
#
# A lot of this is the setup required for running rootless container[1].
#
# [1]: https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md

{
  pkgs,
  lib,
  username,
  ...
}:
let
  inherit (lib)
    optionalAttrs
    optionalString
    hm
    makeBinPath
    ;
  inherit (pkgs.stdenv) isLinux isDarwin;
in
{
  home = {
    packages = with pkgs; [
      podman
    ];

    activation =
      (optionalAttrs isDarwin {
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
            PATH="${dependencies}:$PATH"

            machine_count=$(podman machine list --format json | jq length)
            if (($machine_count == 0)); then
              podman machine init --cpus 6 --memory 7629 --disk-size 55 --rootful
            fi

            PATH="$OLD_PATH"
          '';
      })
      // (optionalAttrs isLinux {
        # Docker requires a daemon to talk to, but on Linux, Podman doesn't need one.
        # For compatibility, Podman provides a socket-activated service.
        #
        # TODO: Home Manager should allow you to pass systemd files to install
        # instead of only taking nix attribute sets. This way I could just pass these
        # files in.
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
      });
  };

  services.flatpak = optionalAttrs isLinux {
    packages = [
      "io.podman_desktop.PodmanDesktop"
    ];
    # Podman Desktop uses X11, but since I set `ELECTRON_OZONE_PLATFORM_HINT=auto` it
    # tries to use Wayland instead, which requires the following permissions.
    overrides."io.podman_desktop.PodmanDesktop".Context.sockets = [
      "system-bus"
      "wayland"
    ];
  };

  system = {
    activation =
      {
        # TODO: So Podman Desktop can find them. Maybe they could launch a login
        # shell to get the PATH instead or respect the `engine.helper_binaries_dir` field
        # in `$XDG_CONFIG_HOME/containers/containers.conf`.
        copyPodmanPrograms = hm.dag.entryAfter [ "writeBoundary" ] (
          ''
            for path in "${pkgs.podman}/bin" "${pkgs.podman}/libexec/podman"; do
              sudo cp "$path/"* /usr/local/bin/
            done
          ''
          # In addition to making the programs below globally available for Podman
          # Desktop, I also need to add setuid.
          + optionalString isLinux ''
            for file in ${pkgs.shadow}/bin/new[ug]idmap; do
              basename="''${file##*/}"
              destination=/usr/local/bin/"$basename"
              sudo cp "$file" "$destination"

              # These are the user, group, and permissions that were set on the newuidmap
              # installed by APT
              sudo chown root:root "$destination"
              sudo chmod 'u+s,g-s,u+rwx,g+rx,o+rx' "$destination"
            done
          ''
        );
      }
      // optionalAttrs isLinux {
        addSubIds = hm.dag.entryAfter [ "writeBoundary" ] ''
          sudo "${pkgs.shadow}/bin/usermod" --add-subuids 100000-165535 --add-subgids 100000-165535 ${username}
        '';
      };
  };

  repository.xdg.configFile = {
    "containers/policy.json".source = "containers/policy.json";
    "containers/registries.conf".source = "containers/registries.conf";
  };
}
