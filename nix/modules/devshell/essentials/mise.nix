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
    # TODO: As of v2026.8.3, `unix_default_file_shell_args` stopped being
    # respected so keep this pinned until it's fixed.
    packages = [ pkgs.multiverse.mise."2026.7.5" ];

    startup.mise.text = ''
      export MISE_TRUSTED_CONFIG_PATHS="$PRJ_ROOT/mise/config.toml"
    '';
  };
}
