{
  pkgs,
  utils,
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib) optional optionalAttrs;
  inherit (utils) projectRoot;
  isCi = config.devshell.name == "ci";
in
{
  imports = [ inputs.nix-script.devshellModules.nix-script ];

  nix-script = {
    config = projectRoot + /nix/nix-script.nix;
    paths = optional (!isCi) (projectRoot + /mise/tasks);
  };

  devshell = {
    # fish is for autocompleting task arguments
    packages = [ pkgs.mise ] ++ optional (!isCi) pkgs.fish;

    startup = optionalAttrs isCi {
      mise.text = ''
        export MISE_TRUSTED_CONFIG_PATHS="$PRJ_ROOT/mise/config.toml"
        # We include all our nix-script environments in the development devshell
        # using `config.nix-script.paths`. Since we already make a GC root for the
        # devshell, we don't need GC roots for individual nix-script environments
        # in a development devshell, only CI.
        #
        # Use the `CI` environment variable so users can load the CI devshell
        # locally without GC roots being made.
        export NIX_SCRIPT_GC_ROOT="''${CI:-}"
      '';
    };
  };
}
