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

      includeCiEssentials =
        devShellSpec:
        devShellSpec
        // {
          inputsFrom = (devShellSpec.inputsFrom or [ ]) ++ [ parts.ciEssentials ];
        };

      makeDevShellOutputs =
        devShellOutputsInfo@{ default, ... }:
        let
          devShellSpecs = removeAttrs devShellOutputsInfo [ "default" ];
        in
        pipe devShellSpecs [
          (mapAttrs (name: spec: spec // { inherit name; }))
          (mapAttrs (name: applyIf (hasPrefix "ci-" name) includeCiEssentials))
          (mapAttrs (_name: mkShellWrapperNoCC))
          (devShells: devShells // { default = devShells.${default}; })
          (devShells: { inherit devShells; })
        ];
    in
    makeDevShellOutputs {
      default = "development";

      development = {
        inputsFrom = with parts; [
          gozip
          speakerctl
          commitMsgHook
          preCommitHook
          checks
          sync
          taskRunner
          taskAutocomplete
          tasks
          vsCode
        ];
        shellHook = ''
          export LEFTHOOK_EXCLUDE='lychee'
        '';
      };

      ci-essentials = { };

      ci-check-for-broken-links = {
        inputsFrom = [ parts.lefthook ];
      };

      ci-renovate = {
        packages = with pkgs; [
          renovate
          gitMinimal
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
}
