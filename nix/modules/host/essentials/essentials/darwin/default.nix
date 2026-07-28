{
  primaryUser,
  utils,
  homeDirectory,
  ...
}:
{
  imports = with utils.modules.darwin; [
    speakers
    ./homebrew.nix
    ./skhd.nix
    ./system-settings.nix
    ./yabai.nix
  ];

  programs = {
    bash.enable = false;
    zsh.enable = false;
  };

  system.primaryUser = primaryUser;
  users.users.${primaryUser}.home = homeDirectory;
  system.stateVersion = 4;
}
