{ primaryUser, ... }: {
  _module.args = {
    utils = import ../../../../utils.nix;
  };

  system = {
    inherit primaryUser;
    stateVersion = 4;
  };

  programs = {
    bash.enable = false;
    zsh.enable = false;
  };
}
