{ pkgs, lib, ... }:
let
  inherit (pkgs) buildEnv;
  inherit (lib) hm;

  fzfWithoutShellConfig = buildEnv {
    name = "fzf-without-shell-config";
    paths = [ pkgs.fzf ];
    pathsToLink = [
      "/bin"
      "/share/man"
    ];
  };
in
{
  home = {
    packages = [ fzfWithoutShellConfig ];

    activation.fzfSetup = hm.dag.entryAfter [ "writeBoundary" ] ''
      history_file="''${XDG_DATA_HOME:-$HOME/.local/share}/fzf/fzf-history.txt"
      mkdir -p "''${history_file%/*}"
      touch "$history_file"
    '';
  };

  fileWrapper.xdg = {
    configFile."fzf/fzfrc.txt".source = "fzf/fzfrc.txt";

    executable."fzf" = {
      source = "fzf/bin";
      recursive = true;
    };
  };
}
