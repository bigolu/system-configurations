{
  perSystem,
  inputs,
  pkgs,
  ...
}:
# SYNC: devshell-base
# All devshells should set `extraSpecialArgs` and import `essentials`.
(perSystem.devshell.eval {
  extraSpecialArgs = { inherit inputs; };

  configuration =
    let
      moduleRoot = ../../modules/devshell;
    in
    {
      imports = [
        (import (moduleRoot + /essentials) {
          name = "ci";
          inherit pkgs;
        })
      ];

      # For the `run` steps in CI workflows
      devshell.packages = [ pkgs.bash ];
    };
}).shell
