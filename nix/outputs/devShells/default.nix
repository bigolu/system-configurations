context@{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (lib) evalModules mapAttrs;

  makeShell =
    {
      context,
      defaultModules ? [ ],
    }:
    {
      name,
      module,
    }:
    (evalModules {
      specialArgs = context // {
        inherit name;
      };
      modules = defaultModules ++ [
        inputs.make-shell.outputs.module
        module
        { inherit name; }
      ];
    }).config.finalPackage;

  makeShells =
    config:
    let
      makeShell' = makeShell config;
    in
    mapAttrs (name: module: makeShell' { inherit name module; });
in
makeShells
  {
    inherit context;
    defaultModules = [ ./modules/common ];
  }
  {
    development = {
      imports = [
        ./modules/direnv.nix
        ./modules/flake-compat.nix
        ./modules/gozip.nix
        ./modules/mise/cli.nix
        ./modules/mise/tasks.nix
        ./modules/mise/task-autocomplete.nix
        ./modules/vscode
        ./modules/lefthook/hooks/check
        ./modules/lefthook/hooks/check-commit-message.nix
        ./modules/lefthook/hooks/sync.nix
        ./modules/speakerctl.nix
      ];

      packages = with pkgs; [
        npins
      ];

      shellHook = ''
        export RUN_FIX_ACTIONS='diff,stage,fail'
      '';
    };

    # CI essentials will be added to all CI shells by the default module.
    ci-essentials = { };

    ci-renovate = {
      packages = with pkgs; [
        renovate
        # Needed by Renovate
        git
        # Needed for the values "gomodTidy" and "gomodUpdateImportPaths" of the
        # Renovate config setting "postUpdateOptions".
        go
      ];

      shellHook = ''
        export RENOVATE_CONFIG_FILE="$PWD/renovate/global/config.json5"
        # If a CI run fails, we'll have all the debug information without
        # having to rerun it.
        export LOG_LEVEL='debug'
        if [[ $CI_DEBUG == 'true' ]]; then
        export RENOVATE_DRY_RUN='full'
        fi

        # Post-Upgrade tasks are executed in the directory of the repo that's
        # currently being processed. I'm going to save the path to this repo so I
        # can run the scripts in it.
        export RENOVATE_BOT_REPO="$PWD"
      '';
    };
  }
