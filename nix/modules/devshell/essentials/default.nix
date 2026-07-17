{ name, pkgs }: { inputs, ... }: {
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

  _module.args = {
    pins = import ../../../pins pkgs;
    utils = import ../../../utils.nix;
    inherit pkgs;
  };

  devshell.name = name;
}
