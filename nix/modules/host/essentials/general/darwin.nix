{ primaryUser, ... }: {
  system = {
    inherit primaryUser;
    stateVersion = 4;
  };

  programs = {
    bash.enable = false;
    zsh.enable = false;
  };
}
