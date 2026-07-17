{
  pkgs,
  myUtils,
  lib,
  ...
}:
let
  inherit (pkgs) linkFarm replaceVars;
  smartPlugLinuxRoot = myUtils.projectRoot + /program-configs/smart-plug/linux;
  inherit (lib) getExe;
in
{
  systemd = {
    packages = [
      (linkFarm "speaker-units" {
        "lib/systemd/system/start-wake-target.service" = smartPlugLinuxRoot + /start-wake-target.service;
        "lib/systemd/system/wake.target" = smartPlugLinuxRoot + /wake.target;
        "lib/systemd/system/speakers.service" = replaceVars (smartPlugLinuxRoot + /speakers.service) {
          speakerctl = getExe pkgs.speakerctl;
        };
      })
    ];

    services = {
      # SYNC: start-wake-target-wanted-by
      start-wake-target.wantedBy = [ "sleep.target" ];
      # SYNC: speakers-wanted-by
      speakers.wantedBy = [
        "graphical.target"
        "wake.target"
      ];
    };
  };

  environment.etc."NetworkManager/dispatcher.d/pre-down.d/turn-off-speakers".source =
    smartPlugLinuxRoot + /turn-off-speakers.bash;
}
