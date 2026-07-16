let
  homeModuleRoot = ../../../modules/home;
  systemModuleRoot = ../../../modules/system;
in
{
  imports = [
    (import (systemModuleRoot + /essentials.nix) {
      system = "x86_64-linux";
      hasGui = true;
      hostName = "comp_2";
    })
  ];

  home-manager.users.biggs = {
    imports = [ (homeModuleRoot + /application-development) ];
  };
}
