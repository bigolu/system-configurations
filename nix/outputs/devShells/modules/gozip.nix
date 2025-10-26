{ pkgs, utils, ... }:
{
  devshell = {
    packagesFrom = [
      (pkgs.mkGoEnv { pwd = utils.projectRoot + /gozip; })
    ];

    startup.go.text = ''
      # Binary names could conflict between projects so store them in a
      # project-specific directory.
      export GOBIN="$PRJ_DATA_DIR/go-bin"
      export PATH="''${GOBIN}''${PATH:+:$PATH}"
    '';
  };
}
