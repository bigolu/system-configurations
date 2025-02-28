{
  lib,
  pkgs,
  utils,
  repositoryDirectory,
  ...
}:
let
  inherit (builtins) readFile;
  inherit (pkgs) speakerctl replaceVars writeTextDir;
  inherit (pkgs.stdenv) isDarwin isLinux;
  inherit (lib)
    optionalAttrs
    getExe
    ;
  inherit (utils) projectRoot;

  smartPlugRoot = "${repositoryDirectory}/smart_plug";

  speakerService =
    let
      speakerServiceName = "speakers.service";
      speakerServiceTemplate = projectRoot + /smart_plug/linux/speakers.service;

      processedTemplate = replaceVars speakerServiceTemplate {
        speakerctl = getExe speakerctl;
      };
    in
    # This way the basename of the file will be `speakerServiceName` which is
    # necessary for config.systemd.units.
    "${writeTextDir speakerServiceName (readFile processedTemplate)}/${speakerServiceName}";
in
{
  repository.home.file = optionalAttrs isDarwin {
    ".hammerspoon/Spoons/Speakers.spoon".source = "${smartPlugRoot}/mac_os/Speakers.spoon";
  };

  home = {
    packages = [ speakerctl ];
  };

  system = optionalAttrs isLinux {
    systemd.units = [
      "${smartPlugRoot}/linux/start-wake-target.service"
      "${smartPlugRoot}/linux/wake.target"
      "${speakerService}"
    ];
    file."/etc/NetworkManager/dispatcher.d/pre-down.d/turn-off-speakers".source =
      "${smartPlugRoot}/linux/turn-off-speakers.bash";
  };
}
