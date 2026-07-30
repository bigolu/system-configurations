{ primaryUser, ... }: {
  system = {
    inherit primaryUser;
    stateVersion = 7;
  };

  programs = {
    bash.enable = false;
    zsh.enable = false;
  };
}
