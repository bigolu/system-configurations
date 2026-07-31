{
  primaryUser,
  myUtils,
  pkgs,
  ...
}:
let
  inherit (myUtils) programConfigRoot;
  inherit (pkgs) symlinkJoin makeWrapper skhd;

  dependencies = symlinkJoin {
    name = "skhd-dependencies";
    paths = with pkgs; [
      skhd
      yabai
      fish
      jq
      bash
    ];
  };

  skhdWithDependencies = symlinkJoin {
    name = "my-${skhd.name}";
    paths = [ skhd ];
    nativeBuildInputs = [ makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/skhd \
        --prefix PATH : ${dependencies}/bin \
        --prefix PATH : ${programConfigRoot + /skhd/bin}
    '';
  };
in
{
  services.skhd = {
    enable = true;
    package = skhdWithDependencies;
  };

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
    fileWrapper = {
      xdg.configFile."skhd/skhdrc".source = "skhd/skhdrc";

      home.file."Library/Keyboard Layouts/NoAccentKeys.bundle".source =
        "keyboard/US keyboard - no accent keys.bundle";
    };

    # By default, a bell sound goes off whenever I use ctrl+/, this disables that.
    targets.darwin.keybindings."^/" = "noop:";
  };
}
