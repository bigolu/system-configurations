{
  lib,
  pkgs,
  specialArgs,
  config,
  ...
}:
let
  inherit (specialArgs) isGui flakeInputs;
  inherit (pkgs.stdenv) isDarwin isLinux;

  stacklineWithoutConfig = pkgs.stdenv.mkDerivation {
    pname = "mystackline";
    version = "0.1";
    src = flakeInputs.stackline;
    installPhase = ''
      mkdir -p $out
      cp -r $src/* $out/
      # remove the config that stackline comes with so I can link mine later
      rm $out/conf.lua
    '';
  };

  mac = lib.mkIf (isGui && isDarwin) {
    repository.symlink = {
      xdg = {
        configFile = {
          "yabai/yabairc".source = "yabai/yabairc";
          "skhd/skhdrc".source = "skhd/skhdrc";
        };
      };

      home.file = {
        ".hammerspoon/init.lua".source = "hammerspoon/init.lua";
        ".hammerspoon/stackline/conf.lua".source = "hammerspoon/stackline/conf.lua";
        "Library/Keyboard Layouts/NoAccentKeys.bundle".source = "keyboard/US keyboard - no accent keys.bundle";
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

  linux = lib.mkIf (isGui && isLinux) {
    repository.symlink = {
      xdg = {
        configFile = {
          # TODO: When COSMIC writes to this file it replaces the symlink with a regular copy :(
          "cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom".source = "cosmic/v1-shortcuts";
        };
      };
    };

    home.activation = {
      installKeyd = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        # Add /usr/bin so scripts can access system programs like sudo/apt
        PATH="$PATH:/usr/bin"

        if ! type -P keyd 1>/dev/null; then
          # The readme[1] links to this unofficial PPA[2].
          #
          # [1]: https://github.com/rvaiya/keyd
          # [2]: https://launchpad.net/~keyd-team/+archive/ubuntu/ppa
          sudo add-apt-repository ppa:keyd-team/ppa
          sudo apt update
          sudo apt install keyd
          sudo systemctl enable keyd
          sudo keyd reload
        fi

        path=/etc/keyd/default.conf
        if [[ ! -e "$path" ]]; then
          sudo mkdir -p "$(dirname "$path")"
          sudo ln --symbolic --force --no-dereference \
            ${config.repository.directory}/dotfiles/keyd/default.conf \
            "$path"
        fi
      '';

      setKeyboardToMacMode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        # Add /usr/bin so scripts can access system programs like sudo/apt
        PATH="$PATH:/usr/bin"

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
        if ! grep -q "$conf_line" <"$conf_file"; then
          # Persist it so it gets set automatically on future boots
          echo "$conf_line" \
            | sudo tee -a "$conf_file"
          sudo update-initramfs -u -k all
        fi
      '';
    };

  };
in
lib.mkMerge [
  mac
  linux
]
