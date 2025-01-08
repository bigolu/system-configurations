{
  pkgs,
  ...
}:
{
  # Using this so Home Manager can include its generated completion scripts
  programs.fish.enable = true;

  home.packages =
    (with pkgs; [
      # For ssh.fish
      ncurses
    ])
    ++ (with pkgs.fishPlugins; [
      autopair-fish
      fish-async-prompt
      done
      # Using this to get shell completion for programs added to the path through
      # nix+direnv. Issue to upstream into direnv:
      # https://github.com/direnv/direnv/issues/443
      fish-completion-sync
    ]);

  repository = {
    symlink.xdg.configFile = {
      "fish/conf.d" = {
        source = "fish/conf.d";
        # I'm recursively linking because I link into this directory in other places.
        recursive = true;
      };
    };
  };
}
