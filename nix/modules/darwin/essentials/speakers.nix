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
}
