{
  pkgs,
  perSystem,
  inputs,
  ...
}:
let
  moduleRoot = ../../devshell-modules;
in
# SYNC: devshell-base
# All devshells should set extraSpecialArgs and import `essentials.nix`.
(perSystem.devshell.eval {
  extraSpecialArgs = { inherit inputs pkgs; };

  configuration = {
    imports = [
      (moduleRoot + "/essentials.nix")
    ];
  };
}).shell
