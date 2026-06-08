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

  system.primaryUser = "biggs";
}
