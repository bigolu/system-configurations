{
  pkgs,
  lib,
  inputs,
  pins,
  config,
  extraModulesPath,
  ...
}:
let
  inherit (lib)
    optional
    hasPrefix
    optionals
    elem
    filterAttrs
    attrValues
    ;
  inherit (pkgs.stdenv) isLinux;

  inherit (config.devshell) name;
  isCiDevShell = hasPrefix "ci-" name;
in
{
  _module.args = {
    pins = import ../../../pins pkgs;
    utils = import ../../../utils.nix { inherit inputs pkgs; };
  };

  imports = [
    "${extraModulesPath}/locale.nix"
    ./mise/cli.nix
  ]
  ++ (with inputs.devshell-modules.devshellModules; [
    minimal
    autocomplete
    state
    gcRoot
  ]);

  # For the `run` steps in CI workflows
  devshell.packages = optional isCiDevShell pkgs.bash;

  gcRoot.roots = {
    flake = {
      inherit inputs;
      exclude = if isLinux then [ "nix-darwin" ] else [ "nix-gl-host-rs" ];
    };

    paths = optionals (!isCiDevShell) (
      attrValues (
        filterAttrs (
          name: pin:
          (name != "__functor")
          && (
            !(elem pin (
              with pins;
              optionals isLinux [
                spoons
                stackline
              ]
            ))
          )
        ) pins
      )
    );
  };
}
