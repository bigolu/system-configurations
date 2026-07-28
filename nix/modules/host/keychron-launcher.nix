{
  system =
    {
      myUtils,
      pkgs,
      primaryUser,
      lib,
      ...
    }:
    let
      inherit (myUtils) programConfigRoot;
      inherit (lib) getExe;
    in
    {
      environment.etc."udev/rules.d/99-keychron-launcher.rules".source =
        programConfigRoot + /keychron-launcher/99-keychron-launcher.rules;

      # The keychron configuration tool requires a web API that's only in Chromium.
      home-manager.users.${primaryUser}.xdg.desktopEntries.keychron-launcher = {
        name = "Keychron Launcher";
        exec = "${getExe pkgs.chromium} --app=https://launcher.keychron.com/ --class=keychron-launcher";
        settings.StartupWMClass = "keychron-launcher";
        icon = pkgs.fetchurl {
          url = "https://upload.wikimedia.org/wikipedia/commons/d/d5/Keychron_icon.svg";
          sha256 = "sha256-JtMtaq9cvsq3N5L7B/8TJIsXmxZ/Xtlwoov3wlXySDE=";
        };
      };
    };
}
