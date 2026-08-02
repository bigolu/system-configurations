{ primaryUser, myUtils, ... }:
let
  inherit (myUtils) programConfigRoot;
  modulesPath = ../../../modules/host;
in
{
  imports = [
    (modulesPath + /essentials)
    (modulesPath + /speakers.nix)
    (modulesPath + /keychron-launcher.nix)
    (modulesPath + /seedbox.nix)
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  environment.etc."sysctl.d/local.conf".source = programConfigRoot + /sysctl/local.conf;
  home-manager.users.${primaryUser}.fileWrapper.xdg.configFile."ghostty/comp-1.ghostty".source =
    "ghostty/comp-1.ghostty";
}
