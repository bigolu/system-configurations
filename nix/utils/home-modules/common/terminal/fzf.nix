{
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs) buildEnv fzf;
  inherit (lib) hm;

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

  home.activation.fzfSetup = hm.dag.entryAfter [ "writeBoundary" ] ''
    history_file="''${XDG_DATA_HOME:-$HOME/.local/share}/fzf/fzf-history.txt"
    mkdir -p "''${history_file%/*}"
    touch "$history_file"
  '';
}
