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
        (moduleRoot + /essentials)
        (moduleRoot + /vscode.nix)
        (moduleRoot + /hk.nix)
        (moduleRoot + /npins.nix)
      ];

      essentials = {
        name = "dev";
        inherit pkgs;
      };

      devshell.startup.dev.text = ''
        export NIX_CONFIG="
          ''${NIX_CONFIG:-}
          extra-repl-overlays = $PRJ_ROOT/nix/repl-overlay.nix
        "
      '';
    };
}).shell
