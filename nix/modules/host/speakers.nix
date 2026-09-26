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
  inherit (pkgs)
    replaceVars
    linkFarm
    speakerctl
    runCommand
    ;
  inherit (lib) getExe pipe;
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
        pipe (speakersLinuxRoot + /turn-off-speakers.nu)
          [
            (
              script:
              let
                name = "turn-off-speakers";
              in
              runCommand name
                {
                  buildInputs = [ pkgs.nushell ];
                  meta.mainProgram = name;
                }
                ''
                  mkdir --parents $out/bin
                  cp ${script} $out/bin/${name}
                  chmod +x $out/bin/${name}
                  patchShebangs $out/bin/${name}
                ''
            )
            getExe
          ];
    };

  darwin = {
    homebrew.casks = [ "hammerspoon" ];

    home-manager.users.${primaryUser}.home.file = {
      ".hammerspoon/init.lua".source = replaceVars (speakersRoot + /mac-os/init.lua) {
        speakerctl = getExe speakerctl;
      };

      ".hammerspoon/Spoons/EmmyLua.spoon/init.lua" = pins.emmylua;
    };
  };
}
.${toString _class}
