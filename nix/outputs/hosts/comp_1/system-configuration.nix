{ primaryUser, ... }:
let
  myUtils = import ../../../my-utils.nix;
  inherit (myUtils) programConfigRoot modules;
in
{
  imports = with modules.system; [
    (essentials { system = "x86_64-linux"; })
    speakers
    keychron-launcher
    seedbox
  ];

  environment.etc."sysctl.d/local.conf".source = programConfigRoot + /sysctl/local.conf;

  home-manager.users.${primaryUser}.fileWrapper.xdg.configFile."ghostty/comp-1.ghostty".source =
    "ghostty/comp-1.ghostty";
}
