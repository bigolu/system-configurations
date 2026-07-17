{
  lib,
  pkgs,
  hasGui,
  ...
}:
let
  inherit (pkgs) stdenv;
  inherit (stdenv.hostPlatform) isDarwin isLinux;
  inherit (lib) mkIf mkMerge;

  mac = mkIf (hasGui && isDarwin) {
    fileWrapper = {
      xdg = {
        configFile = {
          "yabai/yabairc".source = "yabai/yabairc.bash";
          "skhd/skhdrc".source = "skhd/skhdrc";
        };
      };

      home.file = {
        "Library/Keyboard Layouts/NoAccentKeys.bundle".source =
          "keyboard/US keyboard - no accent keys.bundle";
      };
    };

    targets.darwin.keybindings = {
      # By default, a bell sound goes off whenever I use ctrl+/, this disables that.
      "^/" = "noop:";
    };
  };

  linux = mkIf (hasGui && isLinux) {
    fileWrapper.xdg.configFile."keyd/app.conf".source = "keyd/app.conf";

    home.packages = with pkgs; [
      keyd
      # The keychron configuration tool requires a web API that's only in Chrome.
      google-chrome
    ];

    systemd.user.services.keyd-application-mapper = {
      Unit = {
        Description = "Application-Specific mappings for keyd";
        After = "multi-user.target";
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.keyd}/bin/keyd-application-mapper -d";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
in
mkMerge [
  mac
  linux
]
