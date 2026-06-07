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
    optionals
    elem
    filterAttrs
    attrValues
    optionalAttrs
    ;
  inherit (pkgs.stdenv) isLinux;

  inherit (config.devshell) name;
  isCiDevshell = name == "ci";
in
{
  _module.args = {
    pins = import ../../pins pkgs;
    utils = import ../../utils.nix;
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

  extra.locale = optionalAttrs isCiDevshell {
    package = pkgs.glibcLocales.override {
      allLocales = false;
      locales = [ "en_US.UTF-8/UTF-8" ];
    };
  };

  # For the `run` steps in CI workflows
  devshell.packages = optional isCiDevshell pkgs.bash;

  gcRoot.roots = {
    flake = {
      inherit inputs;
      exclude =
        (
          if isLinux then
            [
              "nix-darwin"
            ]
          else
            [ "nix-gl-host-rs" ]
        )
        ++ (optionals isCiDevshell [
          "llm-agents"
          "nix-gl-host-rs"
        ]);
    };

    paths = optionals (!isCiDevshell) (
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
