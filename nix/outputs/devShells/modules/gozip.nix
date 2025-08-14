{ pkgs, utils, ... }:
{
  devshell.packagesFrom = [
    (pkgs.mkGoEnv { pwd = utils.projectRoot + /gozip; })
  ];

  devshell.startup.go.text = ''
    # Binary names could conflict between projects so store them in a
    # project-specific directory.
    export GOBIN="''${direnv_layout_dir:-$PWD/.direnv}/go-bin"
    export PATH="''${GOBIN}''${PATH:+:$PATH}"
  '';
}
