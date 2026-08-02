{ _class, ... }:
{
  darwin.homebrew = {
    enable = true;

    onActivation = {
      cleanup = "zap";
      extraFlags = [ "--quiet" ];
    };

    caskArgs = {
      # Don't quarantine the casks so macOS doesn't warn me before opening any
      # of them.
      no_quarantine = true;
    };
  };
}
.${toString _class}
