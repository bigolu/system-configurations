{ primaryUser, ... }: {
  home-manager.users.${primaryUser} = {
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
}
