{
  pkgs,
  ...
}:
let
  inherit (pkgs) buildEnv fzf;

  fzfWithoutShellConfig = buildEnv {
    name = "fzf-without-shell-config";
    paths = [ fzf ];
    pathsToLink = [
      "/bin"
      "/share/man"
    ];
  };
in
{
  home.packages = [
    fzfWithoutShellConfig
  ];

  repository.xdg = {
    executable."fzf" = {
      source = "fzf/bin";
      recursive = true;
    };
    configFile."fzf/fzfrc.txt".source = "fzf/fzfrc.txt";
  };
}
