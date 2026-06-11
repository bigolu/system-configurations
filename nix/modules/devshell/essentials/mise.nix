{
  pkgs,
  utils,
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib) optional optionalString;
  inherit (utils) projectRoot;
  isCi = config.devshell.name == "ci";
  isDev = config.devshell.name == "dev";
in
{
  imports = [ inputs.nix-script.devshellModules.nix-script ];

  nix-script = {
    config = projectRoot + /nix/nix-script.nix;
    preload = optional isDev (projectRoot + /mise/tasks);
  };

  devshell = {
    # fish is for autocompleting task arguments
    packages = [ pkgs.mise ] ++ optional isDev pkgs.fish;

    startup.mise.text = ''
      export MISE_TRUSTED_CONFIG_PATHS="$PRJ_ROOT/mise/config.toml"
    ''
    + optionalString isCi ''
      # We preload all our nix-script environments into the development
      # devshell so we only need to enable GC root creation in Ci.
      #
      # Use the `CI` environment variable so users can load the CI devshell
      # locally without GC roots being made.
      export NIX_SCRIPT_GC_ROOT="''${CI:-}"
    '';
  };
}
