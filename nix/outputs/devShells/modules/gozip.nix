{ pkgs, utils, ... }:
{
  devshell.packagesFrom = [
    (pkgs.mkGoEnv { pwd = utils.projectRoot + /gozip; })
  ];

  devshell.startup.go.text = ''
    # Binary names could conflict between projects so store them in a
    # project-specific directory.
    export GOBIN="$DEV_SHELL_STATE/go-bin"
    export PATH="''${GOBIN}''${PATH:+:$PATH}"
  '';
}
