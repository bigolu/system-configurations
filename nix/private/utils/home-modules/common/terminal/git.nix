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
