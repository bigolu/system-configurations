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
        (moduleRoot + /npins.nix)
      ];

      devshell.startup.dev.text = ''
        export NIX_CONFIG="
          ''${NIX_CONFIG:-}
          extra-repl-overlays = $PRJ_ROOT/nix/repl-overlay.nix
        "
      '';
    };
}).shell
