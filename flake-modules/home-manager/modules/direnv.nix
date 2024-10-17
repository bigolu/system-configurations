{ pkgs, ... }:
{
  home.packages = with pkgs; [
    direnv
  ];

  repository.symlink.xdg.configFile = {
    "direnv/direnv.toml".source = "direnv/direnv.toml";
  };
}
