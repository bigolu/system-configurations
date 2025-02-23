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
    hm
    ;
  inherit (pkgs.stdenv) isLinux isDarwin;
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

  services.flatpak.packages = optionals (isLinux && isGui) [
    "io.podman_desktop.PodmanDesktop"
  ];

  system.activation = optionalAttrs isDarwin {
    # TODO: So Podman Desktop on macOS can find it. Maybe they could launch a login
    # shell to get the PATH instead or respect the `engine.helper_binaries_dir` field
    # in `$XDG_CONFIG_HOME/containers/containers.conf`.
    addPodmanPathToConfig = hm.dag.entryAfter [ "writeBoundary" ] ''
      sudo cp \
        ${pkgs.podman}/bin/* \
        ${pkgs.podman}/libexec/podman/* \
        ${pkgs.podman-mac-helper}/bin/* \
        /usr/local/bin/
    '';
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
    };
  };
}
