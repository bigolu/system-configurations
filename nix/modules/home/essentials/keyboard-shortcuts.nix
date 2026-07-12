{
  lib,
  pkgs,
  hasGui,
  repositoryDirectory,
  config,
  ...
}:
let
  inherit (pkgs) stdenv;
  inherit (stdenv.hostPlatform) isDarwin isLinux;
  inherit (lib) mkIf hm mkMerge;

  mac = mkIf (hasGui && isDarwin) {
    fileWrapper = {
      xdg = {
        configFile = {
          "yabai/yabairc".source = "yabai/yabairc.bash";
          "skhd/skhdrc".source = "skhd/skhdrc";
        };
      };

      home.file = {
        "Library/Keyboard Layouts/NoAccentKeys.bundle".source =
          "keyboard/US keyboard - no accent keys.bundle";
      };
    };

    targets.darwin.keybindings = {
      # By default, a bell sound goes off whenever I use ctrl+/, this disables that.
      "^/" = "noop:";
    };
  };

  linux = mkIf (hasGui && isLinux) {
    fileWrapper.xdg.configFile."keyd/app.conf".source = "keyd/app.conf";

    home.packages = with pkgs; [
      keyd
      # The keychron configuration tool requires a web API that's only in Chrome.
      google-chrome
    ];

    system = {
      systemd.units = [ "${pkgs.keyd}/lib/systemd/system/keyd.service" ];

      file = {
        "/etc/keyd/default.conf".source = "${repositoryDirectory}/program-configs/keyd/default.conf";
        "/etc/udev/rules.d/99-keychron-launcher.rules".source =
          "${repositoryDirectory}/program-configs/keychron-launcher/99-keychron-launcher.rules";
      };

      activation = {
        # Needs to be before systemd services are started since the
        # keyd-application-mapper service requires my user be in the keyd group and I
        # add myself to that group here.
        addToKeydGroup = hm.dag.entryBefore [ "reloadSystemd" ] ''
          # Add myself to the keyd group so I can use application-specific mappings
          if ! getent group keyd &>/dev/null; then
            sudo groupadd keyd
          fi
          sudo usermod -aG keyd ${config.home.username}
        '';

        restartKeyd = hm.dag.entryAfter [ "installSystemFiles" ] ''
          sudo systemctl restart keyd.service &>/dev/null
        '';
      };
    };

    systemd.user.services.keyd-application-mapper = {
      Unit = {
        Description = "Application-Specific mappings for keyd";
        After = "multi-user.target";
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.keyd}/bin/keyd-application-mapper -d";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
in
mkMerge [
  mac
  linux
]
