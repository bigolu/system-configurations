context@{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (lib) mapAttrs;

  makeShells =
    {
      extraModuleArgs ? { },
      defaultModule ? { },
    }:
    mapAttrs (
      name: module:
      (inputs.devshell.outputs.eval {
        extraSpecialArgs = extraModuleArgs;
        configuration = {
          imports = [
            defaultModule
            module
          ];
          devshell = { inherit name; };
        };
      }).shell
    );
in
makeShells
  {
    extraModuleArgs = context;
    defaultModule = ./modules/essentials.nix;
  }
  {
    development = {
      imports = [
        ./modules/gozip.nix
        ./modules/mise/tasks.nix
        ./modules/mise/task-autocomplete.nix
        ./modules/vscode.nix
        ./modules/lefthook/hooks/check
        ./modules/lefthook/hooks/sync.nix
        pkgs.speakerctl.devshellModule
      ];

      devshell = {
        packages = with pkgs; [ npins ];
        startup.repl-overlay.text = ''
          # TODO
          export LEFTHOOK_EXCLUDE='4-nix-outputs,system'

          export NIX_CONFIG="
            ''${NIX_CONFIG:-}
            extra-repl-overlays = $PWD/nix/repl-overlay.nix
          "
        '';
      };
    };

    # CI essentials will be added to all CI shells by the default module.
    ci-essentials = { };
  }
