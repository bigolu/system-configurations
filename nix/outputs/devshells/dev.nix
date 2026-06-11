{
  pkgs,
  perSystem,
  inputs,
  ...
}:
# SYNC: devshell-base
# All devshells should set `extraSpecialArgs`/`name` and import `essentials`.
(perSystem.devshell.eval {
  extraSpecialArgs = { inherit inputs pkgs; };
  configuration =
    { pkgs, ... }:
    let
      moduleRoot = ../../modules/devshell;
    in
    {
      imports = [
        (moduleRoot + "/essentials")
        { devshell.name = "dev"; }

        (moduleRoot + "/vscode.nix")
        (moduleRoot + "/lefthook.nix")

        # npins
        {
          devshell = {
            packages = [ pkgs.npins ];
            startup.npins.text = ''
              export NPINS_DIRECTORY="$PRJ_ROOT/nix/pins/npins"
            '';
          };
        }
      ];

      devshell.startup.dev.text = ''
        export NIX_CONFIG="
          ''${NIX_CONFIG:-}
          extra-repl-overlays = $PRJ_ROOT/nix/overlays/repl.nix
        "
      '';
    };
}).shell
