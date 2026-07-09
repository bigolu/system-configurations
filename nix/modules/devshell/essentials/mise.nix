{
  pkgs,
  utils,
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib) optional;
  inherit (utils) projectRoot;
  isCi = config.devshell.name == "ci";
  isDev = config.devshell.name == "dev";
in
{
  imports = [ inputs.nix-scene.devshellModules.nix-scene ];

  nix-scene = {
    config = projectRoot + /nix/scene.nix;
    preload = optional isDev (projectRoot + /mise/tasks);
    makeGcRoots = isCi;
  };

  devshell = {
    packages = [ pkgs.mise ];

    startup.mise.text = ''
      export MISE_TRUSTED_CONFIG_PATHS="$PRJ_ROOT/mise/config.toml"
    '';
  };
}
