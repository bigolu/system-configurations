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

  fileWrapper = {
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
