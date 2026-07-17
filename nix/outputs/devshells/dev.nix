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
          name = "dev";
          inherit pkgs;
        })
        (moduleRoot + /vscode.nix)
        (moduleRoot + /hk.nix)

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
          extra-repl-overlays = $PRJ_ROOT/nix/repl-overlay.nix
        "
      '';
    };
}).shell
