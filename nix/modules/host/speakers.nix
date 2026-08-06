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
  speakersRoot = myUtils.programConfigRoot + /speakers;
in
{
  "" =
    let
      speakersLinuxRoot = speakersRoot + /linux;
    in
    {
      systemd = {
        packages = [
          (linkFarm "speaker-units" {
            "lib/systemd/system/start-wake-target.service" = speakersLinuxRoot + /start-wake-target.service;
            "lib/systemd/system/wake.target" = speakersLinuxRoot + /wake.target;
            "lib/systemd/system/speakers.service" = replaceVars (speakersLinuxRoot + /speakers.service) {
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
        speakersLinuxRoot + /turn-off-speakers.bash;
    };

  darwin = {
    homebrew.casks = [ "hammerspoon" ];

    home-manager.users.${primaryUser}.home.file = {
      ".hammerspoon/init.lua".source = replaceVars (speakersRoot + /mac-os/init.lua) {
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
