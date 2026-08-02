{
  _class,
  myUtils,
  lib,
  pkgs,
  primaryUser,
  pins,
  ...
}:
let
  inherit (pkgs) replaceVars linkFarm speakerctl;
  inherit (lib) getExe;
  inherit (myUtils) programConfigRoot;
in
{
  "" =
    let
      smartPlugLinuxRoot = myUtils.programConfigRoot + /smart-plug/linux;
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
            "multi-user.target"
            "wake.target"
          ];
        };
      };

      environment.etc."NetworkManager/dispatcher.d/pre-down.d/turn-off-speakers".source =
        smartPlugLinuxRoot + /turn-off-speakers.bash;
    };

  darwin = {
    homebrew.casks = [ "hammerspoon" ];

    home-manager.users.${primaryUser}.home.file = {
      ".hammerspoon/init.lua".source = replaceVars (programConfigRoot + /smart-plug/mac-os/init.lua) {
        speakerctl = getExe speakerctl;
      };

      ".hammerspoon/Spoons/EmmyLua.spoon" = {
        source = "${pins.spoons}/Source/EmmyLua.spoon";
        # I'm not symlinking the whole directory because EmmyLua is going to
        # generate lua-language-server annotations in there.
        recursive = true;
      };
    };
  };
}
.${toString _class}
