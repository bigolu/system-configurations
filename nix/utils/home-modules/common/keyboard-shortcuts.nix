{
  lib,
  pkgs,
  hasGui,
  repositoryDirectory,
  pins,
  username,
  ...
}:
let
  inherit (pkgs) stdenv;
  inherit (stdenv) isDarwin isLinux;
  inherit (lib) mkIf hm mkMerge;

  stacklineWithoutConfig = stdenv.mkDerivation {
    pname = "mystackline";
    version = "0.1";
    src = pins.stackline;
    installPhase = ''
      mkdir -p $out
      cp -r $src/* $out/
      # remove the config that stackline comes with so I can link mine later
      rm $out/conf.lua
    '';
  };

  mac = mkIf (hasGui && isDarwin) {
    repository = {
      xdg = {
        configFile = {
          "yabai/yabairc".source = "yabai/yabairc.bash";
          "skhd/skhdrc".source = "skhd/skhdrc";
        };
      };

      home.file = {
        ".hammerspoon/init.lua".source = "hammerspoon/init.lua";
        ".hammerspoon/stackline/conf.lua".source = "hammerspoon/stackline/conf.lua";
        "Library/Keyboard Layouts/NoAccentKeys.bundle".source =
          "keyboard/US keyboard - no accent keys.bundle";
      };
    };

    home.file = {
      ".hammerspoon/stackline" = {
        source = stacklineWithoutConfig;
        # I'm recursively linking because I link into this directory in other
        # places.
        recursive = true;
      };
    };

    targets.darwin.keybindings = {
      # By default, a bell sound goes off whenever I use ctrl+/, this disables that.
      "^/" = "noop:";
    };
  };

  linux = mkIf (hasGui && isLinux) {
    repository.xdg.configFile."keyd/app.conf".source = "keyd/app.conf";

    home.packages = [ pkgs.keyd ];

    system = {
      systemd.units = [
        "${pkgs.keyd}/lib/systemd/system/keyd.service"
      ];

      file = {
        "/etc/keyd/default.conf".source = "${repositoryDirectory}/dotfiles/keyd/default.conf";
        "/etc/udev/rules.d/99-keychron-launcher.rules".source =
          "${repositoryDirectory}/dotfiles/keychron-launcher/99-keychron-launcher.rules";
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
          sudo usermod -aG keyd ${username}
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
