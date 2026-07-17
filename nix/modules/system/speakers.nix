{
  pkgs,
  myUtils,
  lib,
  ...
}:
let
  inherit (pkgs) linkFarm replaceVars;
  inherit (myUtils) projectRoot;
  smartPlugRoot = projectRoot + /program-configs/smart-plug;
  inherit (lib) getExe;
in
{
  systemd = {
    packages = [
      (linkFarm "speaker-units" {
        "lib/systemd/system/start-wake-target.service" = smartPlugRoot + /linux/start-wake-target.service;
        "lib/systemd/system/wake.target" = smartPlugRoot + /linux/wake.target;
        "lib/systemd/system/speakers.service" = replaceVars (smartPlugRoot + /linux/speakers.service) {
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

  environment.etc = {
    "NetworkManager/dispatcher.d/pre-down.d/turn-off-speakers".source =
      smartPlugRoot + /linux/turn-off-speakers.bash;
  };
}
