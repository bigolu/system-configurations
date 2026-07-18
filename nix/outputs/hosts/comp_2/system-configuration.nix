let
  homeModuleRoot = ../../../modules/home;
  systemModuleRoot = ../../../modules/system;
in
{ primaryUser, ... }: {
  imports = [
    (import (systemModuleRoot + /essentials) {
      system = "x86_64-linux";
      hasGui = true;
      hostName = "comp_2";
    })
    (systemModuleRoot + /podman.nix)
  ];

  home-manager.users.${primaryUser} = {
    imports = [ (homeModuleRoot + /application-development) ];
  };
}
