{ _class, primaryUser, ... }:
{
  "" = {
    imports = [ ./keyd.nix ];
  };

  darwin = {
    imports = [ ./skhd.nix ];

    system = {
      keyboard = {
        enableKeyMapping = true;
        remapCapsLockToControl = true;
      };

      defaults = {
        NSGlobalDomain = {
          ApplePressAndHoldEnabled = false;
          NSAutomaticQuoteSubstitutionEnabled = false;
        };

        trackpad = {
          Clicking = true;
          Dragging = true;
        };
      };
    };

    home-manager.users.${primaryUser} = {
      fileWrapper.home.file."Library/Keyboard Layouts/NoAccentKeys.bundle".source =
        "keyboard/US keyboard - no accent keys.bundle";

      # By default, a bell sound goes off whenever I use ctrl+/, this disables that.
      targets.darwin.keybindings."^/" = "noop:";
    };
  };
}
.${toString _class}
