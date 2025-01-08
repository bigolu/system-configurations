{
  pkgs,
  ...
}:
{
  # Using this so Home Manager can include its generated completion scripts
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      # This way, if I reload my fish shell with `exec fish` the config files get
      # read again. The default behaviour is for config files to only be sourced
      # once.
      set --unexport __HM_SESS_VARS_SOURCED
      set --unexport __fish_home_manager_config_sourced
    '';
    plugins =
      let
        packages = with pkgs.fishPlugins; [
          autopair-fish
          fish-async-prompt
          done
          # Using this to get shell completion for programs added to the path through
          # nix+direnv. Issue to upstream into direnv:
          # https://github.com/direnv/direnv/issues/443
          fish-completion-sync
        ];
      in
      map (package: {
        name = package.pname;
        src = package;
      }) packages;
  };

  # For ssh.fish
  home.packages = with pkgs; [ ncurses ];

  repository = {
    symlink.xdg.configFile = {
      "fish/conf.d" = {
        source = "fish/conf.d";
        # I'm recursively linking because I link into this directory in other
        # places.
        recursive = true;
      };
    };
  };
}
