{
  pkgs,
  isGui,
  lib,
  ...
}:
let
  inherit (lib)
    optionals
    optionalAttrs
    optionalString
    hm
    escapeShellArgs
    ;
  inherit (pkgs.stdenv) isLinux isDarwin;

  podmanPathsToCopy =
    [
      "${pkgs.podman}/bin"
      "${pkgs.podman}/libexec/podman"
    ]
    ++ optionals isDarwin [
      "${pkgs.podman-mac-helper}/bin"
    ];
in
{
  imports = [
    ../firefox-developer-edition.nix
    ../git.nix
    ../terminal.nix
  ];

  home.packages = with pkgs; [
    cloudflared
    doppler
    direnv
    podman
  ];

  services.flatpak = optionalAttrs (isLinux && isGui) {
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

  system.activation = {
    # TODO: So Podman Desktop can find them. Maybe they could launch a login
    # shell to get the PATH instead or respect the `engine.helper_binaries_dir` field
    # in `$XDG_CONFIG_HOME/containers/containers.conf`.
    copyPodmanPrograms = hm.dag.entryAfter [ "writeBoundary" ] (
      ''
        for path in ${escapeShellArgs podmanPathsToCopy}; do
          sudo cp "$path/"* /usr/local/bin/
        done
      ''
      + optionalString isLinux ''
        sudo cp ${pkgs.shadow}/bin/newuidmap /usr/local/bin/newuidmap
        # These are the user, group, and permissions that were set on the newuidmap
        # installed by APT
        sudo chown root:root /usr/local/bin/newuidmap
        sudo chmod 'u+s,g-s,u+rwx,g+rx,o+rx' /usr/local/bin/newuidmap
      ''
    );
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
