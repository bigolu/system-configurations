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
      default = "local";

      local = {
        inputsFrom = with parts; [
          checks
          gozip
          scriptDependencies
          scriptInterpreter
          speakerctl
          sync
          taskRunner
          vsCode
        ];
      };

      ci-essentials = { };

      ci-check-pull-request = {
        inputsFrom = [ parts.checks ];
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
