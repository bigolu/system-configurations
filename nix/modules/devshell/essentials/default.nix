{ name }:
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
    "${extraModulesPath}/locale.nix"
    ./mise.nix
  ]
  ++ (with inputs.devshell-modules.devshellModules; [
    minimal
    autocomplete
    state
    gcRoot
  ]);

  devshell.name = name;

  extra.locale = optionalAttrs isCi {
    # This contains only the "en_US.UTF-8/UTF-8" locale.
    package = pkgs.glibcLocalesUtf8;
  };

  gcRoot = {
    diff.enable = !isCi;

    roots = {
      flake = {
        inherit inputs;

        exclude = optionals isLinux [ "nix-darwin" ] ++ optionals isCi [ "llm-agents" ];
      };

      paths = optionals (!isCi) (
        filter (pin: !elem pin (with pins; [ __functor ] ++ optionals isLinux [ spoons ])) (attrValues pins)
      );
    };
  };
}
