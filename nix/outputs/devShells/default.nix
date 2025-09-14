context@{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (lib) mapAttrs;

  makeShells =
    { extraModuleArgs, defaultModules }:
    mapAttrs (
      name: module:
      (inputs.devshell.outputs.eval {
        extraSpecialArgs = extraModuleArgs // {
          inherit name;
        };
        configuration = {
          imports = defaultModules ++ [ module ];
          inherit name;
        };
      }).shell
    );
in
makeShells
  {
    extraModuleArgs = context;
    defaultModules = [ ./modules/essentials ];
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
        ./modules/speakerctl.nix
      ];

      devshell = {
        packages = [ pkgs.npins ];
        startup.dev.text = ''
          export RUN_FIX_ACTIONS='diff,stage,fail'
        '';
      };
    };

    # CI essentials will be added to all CI shells by the default module.
    ci-essentials = { };

    ci-renovate = {
      devshell = {
        packages = with pkgs; [
          renovate
          # Needed by Renovate
          git
          # Needed for the values "gomodTidy" and "gomodUpdateImportPaths" of the
          # Renovate config setting "postUpdateOptions".
          go
        ];

        startup.renovate.text = ''
          export RENOVATE_CONFIG_FILE="$PWD/renovate/global/config.json5"
          # If a CI run fails, we'll have all the debug information without
          # having to rerun it.
          export LOG_LEVEL='debug'
          if [[ ''${CI:-} != 'true' ]]; then
            export RENOVATE_DRY_RUN='full'
          fi

          # Post-Upgrade tasks are executed in the directory of the repo that's
          # currently being processed. I'm going to save the path to this repo so I
          # can run the scripts in it.
          export RENOVATE_BOT_REPO="$PWD"
        '';
      };
    };
  }
