context@{
  lib,
  packages,
  utils,
  ...
}:
let
  inherit (builtins) mapAttrs;
  inherit (packages) mkShellNoCC;
  inherit (lib)
    pipe
    hasPrefix
    ;
  inherit (utils) applyIf;

  fragments = import ./fragments.nix context;

  addCiEssentials =
    mkShellArgs:
    mkShellArgs
    // {
      inputsFrom = (mkShellArgs.inputsFrom or [ ]) ++ [ fragments.ciEssentials ];
    };

  addShellHookHelpers =
    mkShellArgs:
    mkShellArgs
    // {
      inputsFrom = (mkShellArgs.inputsFrom or [ ]) ++ [ fragments.shellHookHelpers ];
    };

  makeShells =
    mkShellArgsByName:
    pipe mkShellArgsByName [
      # We add the name to the mkShell arguments so the caller doesn't have to
      # specify it twice.
      (mapAttrs (name: mkShellArgs: mkShellArgs // { inherit name; }))
      (mapAttrs (name: applyIf (hasPrefix "ci-" name) addCiEssentials))
      (mapAttrs (_name: addShellHookHelpers))
      (mapAttrs (_name: mkShellNoCC))
    ];
in
makeShells {
  development = {
    packages = with packages; [
      npins
    ];
    inputsFrom = with fragments; [
      direnv
      gozip
      speakerctl
      lefthookCheckHook
      lefthookSyncHook
      mise
      miseTaskAutocomplete
      miseTasks
      vsCode
    ];
    shellHook = ''
      export RUN_FIX_ACTIONS='fail'
    '';
  };

  # The attrset is empty since the CI essentials will be added to all CI shells
  # automatically.
  ci-essentials = { };

  ci-lychee = {
    inputsFrom = [ fragments.lefthook ];
    shellHook = ''
      export LEFTHOOK_ENABLE_LYCHEE='true'
    '';
  };

  ci-renovate = {
    packages = with packages; [
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
