{
  lib,
  pkgs,
  hasGui,
  repositoryDirectory,
  inputs,
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
    src = inputs.stackline;
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

    system = {
      systemd.units = [
        "${pkgs.keyd}/lib/systemd/system/keyd.service"
      ];

      file."/etc/keyd/default.conf".source = "${repositoryDirectory}/dotfiles/keyd/default.conf";

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

        setKeyboardToMacMode = hm.dag.entryAfter [ "writeBoundary" ] ''
          # source: https://unix.stackexchange.com/questions/121395/on-an-apple-keyboard-under-linux-how-do-i-make-the-function-keys-work-without-t
          #
          # TODO: Why does macOS respect the mode set directly through my keyboard, but
          # Linux doesn't?

          desired_fnmode=1

          current_fnmode_file=/sys/module/hid_apple/parameters/fnmode
          current_fnmode="$(<"$current_fnmode_file")"
          if ((desired_fnmode != current_fnmode)); then
            # Set it for this boot
            echo $desired_fnmode | sudo tee "$current_fnmode_file"
          fi

          conf_file='/etc/modprobe.d/hid_apple.conf'
          conf_line="options hid_apple fnmode=$desired_fnmode"
          if [[ ! -e $conf_file ]] || ! grep -q "$conf_line" <"$conf_file"; then
            # Persist it so it gets set automatically on future boots
            echo "$conf_line" \
              | sudo tee -a "$conf_file"
            sudo update-initramfs -u -k all
          fi
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
