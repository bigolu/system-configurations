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
  inherit (lib)
    optionalAttrs
    optionals
    pipe
    attrValues
    filterAttrs
    elem
    ;
  inherit (pkgs.stdenv.hostPlatform) isLinux isDarwin;
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

  gcRoot.roots = {
    flake = {
      inherit inputs;

      exclude =
        (optionals isLinux [
          "nix-darwin"
        ])
        ++ optionals isDarwin [
          "nix-gl-host-rs"
        ]
        ++ optionals isCi [
          "llm-agents"
          "nix-gl-host-rs"
        ];
    };

    paths = pipe pins [
      (filterAttrs (
        _name: pin:
        !elem pin (
          with pins;
          [
            __functor
          ]
          ++ optionals isLinux [
            spoons
          ]
        )
      ))
      attrValues
    ];
  };
}
