{
  pkgs,
  perSystem,
  inputs,
  ...
}:
# SYNC: devshell-base
# All devshells should set extraSpecialArgs and import `essentials.nix`.
(perSystem.devshell.eval {
  extraSpecialArgs = { inherit inputs pkgs; };
  configuration =
    { pkgs, ... }:
    {
      imports = [
        ./modules/essentials.nix

        ./modules/mise/tasks.nix
        ./modules/mise/task-autocomplete.nix
        ./modules/vscode.nix
        ./modules/lefthook.nix
      ];

      env = [
        {
          name = "NPINS_DIRECTORY";
          eval = "$PRJ_ROOT/nix/pins/npins";
        }
        {
          name = "NIX_CONFIG";
          eval = ''
            "
              ''${NIX_CONFIG:-}
              extra-repl-overlays = $PRJ_ROOT/nix/repl-overlay.nix
            "
          '';
        }
      ];

      devshell.packages = with pkgs; [ npins ];
    };
}).shell
