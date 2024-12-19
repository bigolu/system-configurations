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

  repository.symlink.xdg = {
    configFile = {
      "fish/conf.d/fzf-default-opts.fish".source = "fzf/fzf-default-opts.fish";
    };

    executable."fzf" = {
      source = "fzf/bin";
      recursive = true;
    };
  };

  home.activation.fzfSetup = hm.dag.entryAfter [ "writeBoundary" ] ''
    history_file="''${XDG_DATA_HOME:-$HOME/.local/share}/fzf/fzf-history.txt"
    mkdir -p "$(dirname "$history_file")"
    touch "$history_file"
  '';
}
