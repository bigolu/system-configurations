{
  pkgs,
  inputs,
  extraModulesPath,
  config,
  lib,
  pins,
  ...
}:
let
  inherit (builtins) filter;
  inherit (lib)
    optionalAttrs
    optionals
    attrValues
    elem
    ;
  inherit (pkgs.stdenv.hostPlatform) isLinux;
  isCi = config.devshell.name == "ci";
in
{
  _module.args = {
    pins = import ../../../pins pkgs;
    utils = import ../../../utils.nix;
  };

  imports = [
    ./mise.nix

    # locale
    {
      imports = [ "${extraModulesPath}/locale.nix" ];

      extra.locale = optionalAttrs isCi {
        package = pkgs.glibcLocales.override {
          allLocales = false;
          locales = [ "en_US.UTF-8/UTF-8" ];
        };
      };
    }
  ]
  ++ (with inputs.devshell-modules.devshellModules; [
    minimal
    autocomplete
    state
    gcRoot
  ]);

  gcRoot = {
    diff.enable = !isCi;

    roots = {
      flake = {
        inherit inputs;

        exclude =
          optionals isLinux [
            "nix-darwin"
          ]
          ++ optionals isCi [
            "llm-agents"
          ];
      };

      paths = optionals (!isCi) (
        filter (
          pin:
          !elem pin (
            with pins;
            [
              __functor
            ]
            ++ optionals isLinux [
              spoons
            ]
          )
        ) (attrValues pins)
      );
    };
  };
}
