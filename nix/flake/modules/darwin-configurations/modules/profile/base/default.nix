# This module has the configuration that I always want applied.
_: {
  imports = [
    ./homebrew.nix
    ./nix
    ./nix-darwin.nix
    ./skhd.nix
    ./system-settings.nix
    ./utilities.nix
    ./yabai.nix
  ];

  programs.bash.enable = false;
  programs.zsh.enable = false;
}
