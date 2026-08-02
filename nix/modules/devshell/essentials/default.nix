{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  imports = [
    ./gc-root.nix
    ./locale.nix
    ./mise.nix
  ]
  ++ (with inputs.devshell-modules.devshellModules; [
    autocomplete
    minimal
    state
  ]);

  options.essentials = {
    name = mkOption { type = types.str; };
    pkgs = mkOption { type = types.attrs; };
  };

  config = {
    _module.args = {
      pins = import ../../../pins pkgs;
      myUtils = import ../../../utils.nix;
      inherit (config.essentials) pkgs;
    };

    devshell.name = config.essentials.name;
  };
}
