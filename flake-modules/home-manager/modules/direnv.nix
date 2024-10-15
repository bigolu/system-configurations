{ pkgs, ... }:
{
  home.packages = with pkgs; [
    direnv
  ];

  repository.symlink.xdg.configFile = {
    "direnv/direnv.toml".source = "direnv/direnv.toml";
  };

  xdg.configFile = {
    # TODO: I shouldn't have to do this. Either Nix for direnv should generate
    # this, but not sure how that works generally. I can look at zoxide or
    # doppler package definitions to see how they work. I'm thinking the CLI
    # should be responsible for exporting automplete as part of the build, like
    # types.
    "fish/conf.d/direnv.fish".source = ''${pkgs.runCommand "direnv-config.fish" { }
      "${pkgs.direnv}/bin/direnv hook fish > $out"
    }'';
  };
}
