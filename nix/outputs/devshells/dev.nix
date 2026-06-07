{
  pkgs,
  perSystem,
  inputs,
  ...
}:
# SYNC: devshell-base
# All devshells should set `extraSpecialArgs`, `name`, and import `essentials.nix`.
(perSystem.devshell.eval {
  extraSpecialArgs = { inherit inputs pkgs; };
  configuration =
    {
      pkgs,
      lib,
      pins,
      ...
    }:
    let
      inherit (lib)
        optionals
        elem
        filterAttrs
        attrValues
        ;
      inherit (pkgs.stdenv) isLinux;
      moduleRoot = ../../modules/devshell;
    in
    {
      imports = [
        (moduleRoot + "/essentials.nix")
        { name = "dev"; }

        (moduleRoot + "/mise/tasks.nix")
        (moduleRoot + "/mise/task-autocomplete.nix")
        (moduleRoot + "/vscode.nix")
        (moduleRoot + "/lefthook.nix")
      ];

      devshell = {
        packages = with pkgs; [ npins ];

        startup.dev.text = ''
          export NPINS_DIRECTORY="$PRJ_ROOT/nix/pins/npins"
          export NIX_CONFIG="
            ''${NIX_CONFIG:-}
            extra-repl-overlays = $PRJ_ROOT/nix/overlays/repl.nix
          "
        '';
      };

      gcRoot.roots.paths = attrValues (
        filterAttrs (
          name: pin:
          (name != "__functor")
          && (
            !(elem pin (
              with pins;
              optionals isLinux [
                spoons
                stackline
              ]
            ))
          )
        ) pins
      );

    };
}).shell
