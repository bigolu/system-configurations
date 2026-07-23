{ pkgs, ... }:
let
  inherit (pkgs) buildEnv;

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
  home.packages = [ fzfWithoutShellConfig ];
  # I could use systemd-tmpfile, but that wouldn't work in the portable shell.
  xdg.dataFile."fzf/keep".source = pkgs.emptyFile;

  fileWrapper.xdg = {
    configFile."fzf/fzfrc.txt".source = "fzf/fzfrc.txt";

    executable."fzf" = {
      source = "fzf/bin";
      recursive = true;
    };
  };
}
