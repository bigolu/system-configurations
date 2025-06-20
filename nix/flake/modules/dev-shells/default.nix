moduleContext@{ lib, utils, ... }:
{
  perSystem =
    perSystemContext@{ pkgs, ... }:
    let
      inherit (builtins) mapAttrs;
      inherit (pkgs) mkShellWrapperNoCC;
      inherit (lib)
        pipe
        hasPrefix
        ;
      inherit (utils) applyIf;

      parts = import ./parts.nix (moduleContext // perSystemContext);

      addCiEssentials =
        devShellArgs:
        devShellArgs
        // {
          inputsFrom = (devShellArgs.inputsFrom or [ ]) ++ [ parts.ciEssentials ];
        };

      makeDevShellOutputs =
        { default, devShells }:
        pipe devShells [
          # There are no dev shell arguments since the CI essentials will be added
          # to the arguments below.
          (devShells: devShells // { ci-essentials = { }; })
          # We add the name to the dev shell arguments so the caller doesn't have to
          # specify it twice.
          (mapAttrs (name: devShellArgs: devShellArgs // { inherit name; }))
          (mapAttrs (name: applyIf (hasPrefix "ci-" name) addCiEssentials))
          (mapAttrs (_name: mkShellWrapperNoCC))
          (devShells: devShells // { default = devShells.${default}; })
          (devShells: { inherit devShells; })
        ];
    in
    makeDevShellOutputs {
      default = "development";

      devShells = {
        development = {
          inputsFrom = with parts; [
            gozip
            speakerctl
            check
            sync
            taskRunner
            taskAutocomplete
            tasks
            vsCode
          ];
          shellHook = ''
            export RUN_FIX_ACTIONS='fail'
          '';
        };

        ci-check-for-broken-links = {
          inputsFrom = [ parts.lefthook ];
          shellHook = ''
            export LEFTHOOK_ENABLE_LYCHEE='true'
          '';
        };

        ci-renovate = {
          packages = with pkgs; [
            renovate
            # Needed by Renovate
            git
            # Needed for the Renovate config option `postUpdateOptions: ["gomodTidy"]`
            go
          ];
          shellHook = ''
            export RENOVATE_CONFIG_FILE="$PWD/renovate/global/config.json5"
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
      };
    };
}
