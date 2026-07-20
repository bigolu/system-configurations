{ config, ... }: {
  imports = [
    ./homebrew.nix
    ./nix
    ./nix-darwin.nix
    ./skhd.nix
    ./system-settings.nix
    ./utilities.nix
    ./yabai.nix
    ./speakers.nix
    ./keyboard.nix
  ];

  _module.args = { inherit (config.system) primaryUser; };

  programs = {
    bash.enable = false;
    zsh.enable = false;
  };

  system.primaryUser = "biggs";
}
