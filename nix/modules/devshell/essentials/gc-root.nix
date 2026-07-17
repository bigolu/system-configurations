{
  pkgs,
  inputs,
  config,
  lib,
  pins,
  ...
}:
let
  inherit (builtins) filter;
  inherit (lib) optionals attrValues elem;
  inherit (pkgs.stdenv.hostPlatform) isLinux;
  isCi = config.devshell.name == "ci";
in
{
  imports = [ inputs.devshell-modules.devshellModules.gcRoot ];

  gcRoot.roots = {
    flake = {
      inherit inputs;
      exclude = optionals isLinux [ "nix-darwin" ] ++ optionals isCi [ "llm-agents" ];
    };

    paths = optionals (!isCi) (
      filter (pin: !elem pin (with pins; [ __functor ] ++ optionals isLinux [ spoons ])) (attrValues pins)
    );
  };
}
