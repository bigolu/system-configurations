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
        PATH="$PATH:/usr/bin:/bin:${pkgs.moreutils}/bin"

        speakerctl_directory='/opt/speaker'
        sudo mkdir -p "$speakerctl_directory"
        speakerctl_path="$speakerctl_directory/speakerctl"
        sudo ln --symbolic --force --no-dereference \
          ${getExe speakerctl} \
          "$speakerctl_path"

        # I'm using install here because NetworkManager won't run the script unless
        # it's owned by root.
        sudo install \
          --compare -D --no-target-directory \
          --owner=root --group=root --mode='u=rwx,g=r,o=r' \
          ${config.repository.directory}/dotfiles/smart_plug/linux/turn-off-speakers.bash \
          /etc/NetworkManager/dispatcher.d/pre-down.d/turn-off-speakers

        function set_up_service {
          service_base_name="$1"
          service_name=${config.repository.directory}/dotfiles/smart_plug/linux/"$service_base_name"

          if systemctl list-unit-files "$service_base_name" 1>/dev/null 2>&1; then
            # This will unlink it
            chronic sudo systemctl disable "$service_base_name"
          fi
          # Ideally, I'd restart the service as well, but this would turn my speakers
          # on and off. And since I can't tell from Home Manager if any relevant
          # files actually changed, I'd do it on every Home Manager reload, which
          # would get annoying. Instead, I'll do the restart in lefthook.
          chronic sudo systemctl link "$service_name"
          chronic sudo systemctl enable "$service_base_name"
        }
        set_up_service 'smart-plug-off.service'
        set_up_service 'smart-plug-on.service'
      '';
    };
  };
}
