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
        sudo -u ${primaryUser} /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        {
          echo
          echo 'eval "$('"$prefix"'/bin/brew shellenv zsh)"'
        } >> ${config.home-manager.users.${primaryUser}.home.homeDirectory}/.zprofile
      fi
    '';

    homebrew = {
      enable = true;

      onActivation = {
        cleanup = "zap";
        extraFlags = [ "--quiet" ];
      };

      # Ensure macOS doesn't warn me when I first open a cask.
      caskArgs.no_quarantine = true;
    };
  };
}
.${toString _class}
