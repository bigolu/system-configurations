{
  pkgs,
  ...
}:
{
  # Using this so Home Manager can include its generated completion scripts
  programs.fish.enable = true;

  home.packages = with pkgs.fishPlugins; [
    autopair-fish
    fish-async-prompt
    done
  ];

  repository.xdg.configFile."fish/conf.d".source = "fish/conf.d";
}
