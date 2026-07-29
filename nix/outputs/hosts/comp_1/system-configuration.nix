{ primaryUser, ... }:
let
  utils = import ../../../utils.nix;
  inherit (utils) programConfigRoot modules;
in
{
  imports = with modules.system; [
    (essentials {
      system = "x86_64-linux";
      hostName = "comp_1";
    })
    speakers
    nvidia-suspension-fix
    keychron-launcher
    seedbox
  ];

  environment.etc."sysctl.d/local.conf".source = programConfigRoot + /sysctl/local.conf;

  home-manager.users.${primaryUser}.fileWrapper.xdg.configFile."ghostty/comp-1.ghostty".source =
    "ghostty/comp-1.ghostty";
}
