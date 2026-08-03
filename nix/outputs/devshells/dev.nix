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

  configuration = {
    imports = map (path: ../../modules/devshell + path) [
      /essentials
      /vscode.nix
      /hk.nix
      /npins.nix
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
