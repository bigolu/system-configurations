{
  myUtils,
  pkgs,
  primaryUser,
  ...
}:
let
  inherit (myUtils) programConfigRoot;
in
{
  environment.etc."udev/rules.d/99-keychron-launcher.rules".source =
    programConfigRoot + /keychron-launcher/99-keychron-launcher.rules;

  # The keychron configuration tool requires a web API that's only in Chrome.
  home-manager.users.${primaryUser}.home.packages = [ pkgs.google-chrome ];
}
