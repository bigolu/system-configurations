{
  pkgs,
  ...
}:
{
  home = {
    packages = with pkgs; [
      neovim
    ];
  };

  repository.symlink.xdg.configFile = {
    "nvim" = {
      source = "neovim";
    };
  };
}
