{
  pkgs,
  perSystem,
  inputs,
  ...
}:
let
  moduleRoot = ../../modules/devshell;
in
# SYNC: devshell-base
# All devshells should set `extraSpecialArgs`, `name`, and import `essentials.nix`.
(perSystem.devshell.eval {
  extraSpecialArgs = { inherit inputs pkgs; };
  configuration =
    { pkgs, ... }:
    {
      imports = [
        (moduleRoot + "/essentials.nix")
        { name = "dev"; }

        (moduleRoot + "/mise/tasks.nix")
        (moduleRoot + "/mise/task-autocomplete.nix")
        (moduleRoot + "/vscode.nix")
        (moduleRoot + "/lefthook.nix")
      ];

      env = [
        {
          name = "NPINS_DIRECTORY";
          eval = "\"$PRJ_ROOT/nix/pins/npins\"";
        }
        {
          name = "NIX_CONFIG";
          eval = ''
            "
              ''${NIX_CONFIG:-}
              extra-repl-overlays = $PRJ_ROOT/nix/overlays/repl.nix
            "
          '';
        }
      ];

      devshell.packages = with pkgs; [ npins ];
    };
}).shell
