{
  lib,
  pkgs,
  repositoryDirectory,
  ...
}:
let
  inherit (pkgs) speakerctl;
  inherit (pkgs.stdenv) isDarwin;
  inherit (lib)
    optionalAttrs
    ;

  smartPlugRoot = "${repositoryDirectory}/smart_plug";
in
{
  fileWrapper.home.file = optionalAttrs isDarwin {
    ".hammerspoon/Spoons/Speakers.spoon".source = "${smartPlugRoot}/mac_os/Speakers.spoon";
  };

  home = {
    packages = [ speakerctl ];
  };
}
