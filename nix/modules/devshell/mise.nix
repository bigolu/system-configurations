{
  pkgs,
  utils,
  lib,
  config,
  ...
}:
let
  inherit (lib) optionals;
  inherit (utils) projectRoot;
  isCi = config.devshell.name == "ci";
in
{
  nix-script = {
    config = projectRoot + /nix/nix-script.nix;
    paths = optionals (!isCi) [ (projectRoot + /mise/tasks) ];
  };

  devshell = {
    packages =
      with pkgs;
      [
        mise
        # For running tasks
        nix-script
      ]
      ++ optionals (!isCi) [
        # For autocomplete
        fish
      ];

    startup.mise.text = ''
      export MISE_TRUSTED_CONFIG_PATHS="$PRJ_ROOT/mise/config.toml"
      # We include all our nix-script environments in the development devshell
      # using `config.nix-script.paths`. Since we already make a GC root for the
      # devshell, we don't need GC roots for individual nix-script environments
      # in a development devshell, only CI.
      export NIX_SCRIPT_GC_ROOT="''${CI:-}"
    '';
  };
}
