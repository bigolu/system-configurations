{
  pkgs,
  perSystem,
  inputs,
  ...
}:
# SYNC: devshell-base
# All devshells should set `extraSpecialArgs` and import `essentials`.
(perSystem.devshell.eval {
  extraSpecialArgs = { inherit inputs pkgs; };

  configuration =
    { pkgs, ... }:
    let
      moduleRoot = ../../modules/devshell;
    in
    {
      imports = [ (import (moduleRoot + /essentials) { name = "ci"; }) ];
      # For the `run` steps in CI workflows
      devshell.packages = [ pkgs.bash ];
    };
}).shell
