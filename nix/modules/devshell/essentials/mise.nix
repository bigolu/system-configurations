{
  pkgs,
  myUtils,
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib) optional;
  inherit (myUtils) projectRoot;
  isDev = config.devshell.name == "dev";
in
{
  imports = [ inputs.nix-scene.devshellModules.nix-scene ];

  nix-scene = {
    config = projectRoot + /nix/scene.nix;
    preload = optional isDev (projectRoot + /mise/tasks);
  };

  devshell = {
    packages = with pkgs; [
      mise
      # These are for autocomplete
      pkl
      nushell
    ];

    startup.mise.text = ''
      export MISE_TRUSTED_CONFIG_PATHS="$PRJ_ROOT/mise/config.toml"
      # TODO: This setting isn't being respected from the config file
      export MISE_UNIX_DEFAULT_FILE_SHELL_ARGS='nix-scene'
    '';
  };
}
