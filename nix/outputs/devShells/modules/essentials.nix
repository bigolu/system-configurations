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
  imports = [
    "${extraModulesPath}/locale.nix"
    ./mise/cli.nix
  ]
  ++ (with inputs.devshell-modules.outputs.devshellModules; [
    minimal
    autocomplete
    state
    secrets
    gcRoot
  ]);

  # For the `run` steps in CI workflows
  devshell.packages = optional isCiDevShell pkgs.bash;

  secrets.dotenv.enable = true;

  gcRoot.roots = {
    flake = {
      inherit inputs;
      exclude =
        if isLinux then
          [ "nix-darwin" ]
        else
          [
            "nix-gl-host"
            "openrgb-udev-rules"
          ];
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
