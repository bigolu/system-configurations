{
  lib,
  pkgs,
  utils,
  ...
}:
let
  inherit (pkgs) runCommand;
  inherit (lib) getExe;
  inherit (utils) projectRoot;
in
{
  home.packages = [ pkgs.bat ];
  fileWrapper.xdg.configFile."bat".source = "bat";

  xdg.cacheFile.bat = {
    recursive = true;
    source = runCommand "bat-cache" { } ''
      BAT_CACHE_PATH=$out \
        BAT_CONFIG_DIR=${projectRoot + /program-configs/bat} \
        ${getExe pkgs.bat} cache --build
    '';
  };
}
