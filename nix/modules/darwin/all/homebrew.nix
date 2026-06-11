{
  homebrew = {
    enable = true;

    onActivation = {
      cleanup = "zap";
      extraFlags = [ "--quiet" ];
    };

    casks = [
      "ghostty"
      "hammerspoon"
      "visual-studio-code"
      "google-chrome"
      "podman-desktop"
      "devpod"
    ];

    caskArgs = {
      # Don't quarantine the casks so macOS doesn't warn me before opening any
      # of them.
      no_quarantine = true;
    };
  };
}
