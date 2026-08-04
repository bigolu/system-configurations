{ _class, lib, ... }:
{
  darwin = {
  # Install homebrew before nix-darwin's homebrew activation runs.
  system.activationScripts.homebrew.text = lib.mkBefore ''
    if [[ ! -d /opt/homebrew ]]; then
      NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
  '';

  homebrew = {
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
  };
}
.${toString _class}
