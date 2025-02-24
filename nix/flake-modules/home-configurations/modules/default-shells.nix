_: {
  repository.home.file = {
    ".bashrc" = {
      source = "default-shells/bashrc.bash";
      force = true;
    };
    ".zshrc".source = "default-shells/zshrc.zsh";
    ".bash_profile".source = "default-shells/bash_profile.bash";
  };
}
