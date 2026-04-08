{
  pkgs,
  ...
}:
{
  home.packages = with pkgs.fishPlugins; [
    pkgs.fish
    async-prompt
    done
  ];

  repository.xdg.configFile."fish/conf.d" = {
    source = "fish/conf.d";
    recursive = true;
  };
}
