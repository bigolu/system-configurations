{
  lib,
  pkgs,
  isGui,
  config,
  ...
}:
let
  inherit (pkgs) speakerctl;
  inherit (pkgs.stdenv) isDarwin isLinux;
  inherit (lib) optionalAttrs getExe hm;
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
        PATH="$PATH:/usr/bin:/bin"

        speakerctl_path=/opt/speaker/speakerctl
        if [[ ! -e "$speakerctl_path" ]]; then
          sudo mkdir -p "$(dirname "$speakerctl_path")"
          sudo ln --symbolic --force --no-dereference \
            ${getExe speakerctl} \
            "$speakerctl_path"
        fi

        turn_off_speakers_path=/etc/NetworkManager/dispatcher.d/pre-down.d/turn-off-speakers
        if [[ ! -e "$turn_off_speakers_path" ]]; then
          sudo mkdir -p "$(dirname "$turn_off_speakers_path")"
          sudo ln --symbolic --force --no-dereference \
            ${config.repository.directory}/dotfiles/smart_plug/linux/turn-off-speakers.bash \
            "$turn_off_speakers_path"
        fi

        service_name='smart-plug.service'
        if ! systemctl list-unit-files "$service_name" 1>/dev/null 2>&1; then
          sudo systemctl link \
            ${config.repository.directory}/dotfiles/smart_plug/linux/"$service_name"
          sudo systemctl enable "$service_name"
          sudo systemctl start "$service_name"
        fi
      '';
    };
  };
}
