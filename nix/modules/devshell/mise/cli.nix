{ pkgs, utils, ... }:
{
  nix-script.config = utils.projectRoot + /nix/nix-script.nix;

  devshell = {
    packages = with pkgs; [
      mise
      # For running tasks
      nix-script
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
