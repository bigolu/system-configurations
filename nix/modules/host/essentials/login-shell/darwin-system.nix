{ primaryUser, ... }: {
  home-manager.users.${primaryUser}.fileWrapper.home.file = {
    ".bashrc".source = "login-shell/bashrc.bash";
    ".zshrc".source = "login-shell/zshrc.zsh";
  };
}
