{ config, ... }:
{
  homebrew = {
    enable = true;

    onActivation = {
      cleanup = "zap";
      extraFlags = [ "--quiet" ];
    };

    casks = [
      "hammerspoon"
      "visual-studio-code"
      "google-chrome"
      "nightfall"
      "podman-desktop"
      "devpod"
    ];

    caskArgs = {
      # Don't quarantine the casks so macOS doesn't warn me before opening any
      # of them.
      no_quarantine = true;
    };
  };

  # TODO: https://github.com/nix-darwin/nix-darwin/issues/663
  system.activationScripts.postActivation.text = ''
    # Hammerspoon won't have any of my nix profile /bin directories on its path so
    # below I'm copying the programs it needs into a directory that is on its $PATH.
    #
    # The stackline plugin needs yabai.
    test -e /usr/local/bin/yabai && rm /usr/local/bin/yabai
    cp ${config.services.yabai.package}/bin/yabai /usr/local/bin/
  '';
}
