{
  _class,
  lib,
  config,
  primaryUser,
  ...
}:
{
  darwin = {
    # Install homebrew before nix-darwin's homebrew activation runs.
    system.activationScripts.homebrew.text = lib.mkBefore ''
      prefix=/opt/homebrew
      if [[ ! -d $prefix ]]; then
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo 'eval "$("$prefix/bin/brew" shellenv)"' >> ${
          config.home-manager.users.${primaryUser}.home.homeDirectory
        }/.zprofile
      fi
    '';

    homebrew = {
      enable = true;

      onActivation = {
        cleanup = "zap";
        extraFlags = [ "--quiet" ];
      };

      # Don't quarantine the casks so macOS doesn't warn me before opening any
      # of them.
      caskArgs.no_quarantine = true;
    };
  };
}
.${toString _class}
