{ primaryUser, myUtils, ... }:
let
  inherit (myUtils) programConfigRoot;
in
{
  imports = map (path: ../../../modules/host + path) [
    /essentials
    /speakers.nix
    /keychron-launcher.nix
    /seedbox.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  environment.etc."sysctl.d/local.conf".source = programConfigRoot + /sysctl/local.conf;
  home-manager.users.${primaryUser}.fileWrapper.xdg.configFile."ghostty/comp-1.ghostty".source =
    "ghostty/comp-1.ghostty";
}
