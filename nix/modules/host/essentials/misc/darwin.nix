{ primaryUser, ... }: {
  system = {
    inherit primaryUser;
    stateVersion = 7;

    # `AutoBoot` automatically turns the computer on when the lid opens. I
    # disable it to stop my computer from accidentally turning on while I'm
    # working on it.
    #
    # TODO: This option is marked internal
    nvram.variables."AutoBoot" = "%00";

    defaults = {
      dock = {
        autohide = true;
        mru-spaces = false;
      };

      LaunchServices = {
        LSQuarantine = false;
      };
    };

    activationScripts.applySystemSettingsImmediately.text = ''
      # Apply settings immediately so I don't have to logout/reboot.
      # source: https://medium.com/@zmre/nix-darwin-quick-tip-activate-your-preferences-f69942a93236
      /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

      # TODO: Some settings may not apply without doing this:
      # https://github.com/nix-darwin/nix-darwin/issues/658#issuecomment-1557604877
      killall Dock
    '';
  };

  programs = {
    bash.enable = false;
    zsh.enable = false;
  };
}
