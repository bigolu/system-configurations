{ _class, pkgs, ... }:
{
  homeManager = {
    home.packages = with pkgs; [
      git
      delta
      difftastic
      mergiraf
      git-absorb
    ];

    fileWrapper.xdg = {
      configFile."git".source = "git";

      executable."git" = {
        source = "git/bin";
        recursive = true;
      };
    };
  };
}
.${toString _class}
