{
  lib,
  pkgs,
  isGui,
  config,
  utils,
  ...
}:
let
  inherit (builtins) readFile;
  inherit (pkgs) speakerctl replaceVars writeTextDir;
  inherit (pkgs.stdenv) isDarwin isLinux;
  inherit (lib)
    optionalAttrs
    getExe
    hm
    fileset
    ;
  inherit (utils) projectRoot;

  speakerService =
    let
      speakerServiceName = "speakers.service";

      speakerServiceTemplate = "${
        fileset.toSource {
          root = projectRoot + /dotfiles/smart_plug/linux;
          fileset = projectRoot + "/dotfiles/smart_plug/linux/${speakerServiceName}";
        }
      }/${speakerServiceName}";

      processedTemplate = replaceVars speakerServiceTemplate {
        speakerctl = getExe speakerctl;
      };
    in
    # This way the basename of the file will be `speakerServiceName` which is
    # necessary for the Bash function set_up_unit below.
    "${writeTextDir speakerServiceName (readFile processedTemplate)}/${speakerServiceName}";
in
optionalAttrs isGui {
  repository.symlink.home.file = optionalAttrs isDarwin {
    ".hammerspoon/Spoons/Speakers.spoon".source = "smart_plug/mac_os/Speakers.spoon";
  };

  home = {
    packages = [ speakerctl ];

    activation = optionalAttrs isLinux {
      installSpeakerService = hm.dag.entryAfter [ "writeBoundary" ] ''
        # Add /usr/bin so scripts can access system programs like sudo/apt
        # Apparently macOS hasn't merged /bin and /usr/bin so add /bin too.
        PATH="$PATH:/usr/bin:/bin:${pkgs.moreutils}/bin"

        # Apparently, NetworkManager's shutdown is not handled by systemd when the
        # system suspends[1]. Instead, it shuts itself down after receiving a dbus
        # signal from logind. As such, I'm registering a script to run before
        # NetworkManager shuts down that will turn my speakers off.
        #
        # I'm using the install command here because NetworkManager won't run the
        # script unless it's owned by root.
        #
        # [1]: https://unix.stackexchange.com/a/687849
        sudo install \
          --compare -D --no-target-directory \
          --owner=root --group=root --mode='u=rwx,g=r,o=r' \
          ${config.repository.directory}/dotfiles/smart_plug/linux/turn-off-speakers.bash \
          /etc/NetworkManager/dispatcher.d/pre-down.d/turn-off-speakers

        function set_up_unit {
          unit_name="$1"
          unit_base_name="''${unit_name##*/}"

          if systemctl list-unit-files "$unit_base_name" 1>/dev/null 2>&1; then
            # This will unlink it
            chronic sudo systemctl disable "$unit_base_name"
          fi
          chronic sudo systemctl link "$unit_name"
          chronic sudo systemctl enable "$unit_base_name"
        }
        set_up_unit ${config.repository.directory}/dotfiles/smart_plug/linux/start-wake-target.service
        set_up_unit ${config.repository.directory}/dotfiles/smart_plug/linux/wake.target
        set_up_unit ${speakerService}
      '';
    };
  };
}
