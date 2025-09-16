{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    git
    delta
    difftastic
    mergiraf
    partialPackages.git-extras
  ];

  repository = {
    xdg = {
      configFile = {
        "git/config".source = "git/config";
        "git/attributes".source = "git/attributes";
      };

      executable."git" = {
        source = "git/bin";
        recursive = true;
      };
    };
  };
}
