{
  system =
    {
      pkgs,
      myUtils,
      lib,
      ...
    }:
    let
      inherit (pkgs) linkFarm replaceVars;
      smartPlugLinuxRoot = myUtils.programConfigRoot + /smart-plug/linux;
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
    };

  darwin =
    {
      lib,
      pkgs,
      utils,
      pins,
      primaryUser,
      ...
    }:
    let
      inherit (pkgs) speakerctl replaceVars;
      inherit (lib) getExe;
      inherit (utils) programConfigRoot;
    in
    {
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
