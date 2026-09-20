{
  inputs,
  config,
  lib,
  ...
}:
let
  inherit (lib) optionals;
  isCi = config.devshell.name == "ci";
in
{
  imports = [ inputs.devshell-modules.devshellModules.gcRoot ];

  gcRoot.roots.flake = {
    inherit inputs;
    exclude = optionals isCi [ "llm-agents" ];
  };
}
