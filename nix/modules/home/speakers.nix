{
  lib,
  pkgs,
  utils,
  pins,
  ...
}:
let
  inherit (pkgs) speakerctl replaceVars;
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
  inherit (lib) optionalAttrs getExe;
  inherit (utils) projectRoot;
in
{
  home.file = optionalAttrs isDarwin {
    ".hammerspoon/init.lua".source = replaceVars (projectRoot + /program-configs/smart-plug/mac-os/init.lua) {
      speakerctl = getExe speakerctl;
    };

    ".hammerspoon/Spoons/EmmyLua.spoon" = {
      # TODO: I should do a sparse checkout to get the single Hammerspoon Spoon I
      # need. issue: https://github.com/NixOS/nix/issues/5811
      source = "${pins.spoons}/Source/EmmyLua.spoon";
      # I'm not symlinking the whole directory because EmmyLua is going to generate
      # lua-language-server annotations in there.
      recursive = true;
    };
  };
}
