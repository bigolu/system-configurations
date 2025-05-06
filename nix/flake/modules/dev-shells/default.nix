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
        escapeShellArg
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

      addTagToLefthookExclude = tag: ''
        tag=${escapeShellArg tag}

        if [[ -z ''${LEFTHOOK_EXCLUDE+set} ]]; then
          export LEFTHOOK_EXCLUDE=""
        fi

        if [[ -z $LEFTHOOK_EXCLUDE ]]; then
          LEFTHOOK_EXCLUDE="$tag"
        else
          LEFTHOOK_EXCLUDE+=",$tag"
        fi
      '';
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
        shellHook = addTagToLefthookExclude "lychee";
      };

      ci-essentials = { };

      ci-check-for-broken-links = {
        inputsFrom = [ parts.lefthook ];
      };

      ci-renovate = {
        packages = with pkgs; [
          renovate
          gitMinimal
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
