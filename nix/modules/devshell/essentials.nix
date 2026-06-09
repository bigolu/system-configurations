{
  pkgs,
  inputs,
  extraModulesPath,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isLinux;
in
{
  _module.args = {
    pins = import ../../pins pkgs;
    utils = import ../../utils.nix;
  };

  imports = [
    "${extraModulesPath}/locale.nix"
    ./mise/cli.nix
    inputs.nix-script.devshellModules.nix-script
  ]
  ++ (with inputs.devshell-modules.devshellModules; [
    minimal
    autocomplete
    state
    gcRoot
  ]);

  gcRoot.roots.flake = {
    inherit inputs;
    exclude = if isLinux then [ "nix-darwin" ] else [ "nix-gl-host-rs" ];
  };
}
