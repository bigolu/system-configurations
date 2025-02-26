{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    optionalAttrs
    hm
    makeBinPath
    ;
  inherit (pkgs.stdenv) isLinux isDarwin;
in
{
  imports = [
    ../firefox-developer-edition.nix
    ../git.nix
    ../terminal.nix
  ];

  home = {
    packages = with pkgs; [
      cloudflared
      doppler
      direnv
      podman
    ];

    activation = optionalAttrs isDarwin {
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
    };
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
    systemd.units = [
      "${pkgs.podman}/lib/systemd/system/podman.socket"
      "${pkgs.podman}/lib/systemd/system/podman.service"
    ];

    activation = {
      # TODO: So Podman Desktop can find them. Maybe they could launch a login
      # shell to get the PATH instead or respect the `engine.helper_binaries_dir` field
      # in `$XDG_CONFIG_HOME/containers/containers.conf`.
      copyPodmanPrograms = hm.dag.entryAfter [ "writeBoundary" ] ''
        for path in "${pkgs.podman}/bin" "${pkgs.podman}/libexec/podman"; do
          sudo cp "$path/"* /usr/local/bin/
        done
      '';
    };
  };

  repository = {
    home.file = {
      ".yashrc".source = "yash/yashrc";
      ".cloudflared/config.yaml".source = "cloudflared/config.yaml";
    };

    xdg.configFile = {
      "ipython/profile_default/ipython_config.py".source = "python/ipython/ipython_config.py";
      "ipython/profile_default/startup" = {
        source = "python/ipython/startup";
        # I'm linking recursively because ipython makes files in this directory
        recursive = true;
      };
      "direnv/direnv.toml".source = "direnv/direnv.toml";
      "containers/policy.json".source = "containers/policy.json";
      "containers/registries.conf".source = "containers/registries.conf";
    };
  };
}
