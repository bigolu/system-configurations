{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    gitMinimal
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
