moduleContext@{ lib, ... }:
{
  perSystem =
    perSystemContext@{ pkgs, ... }:
    let
      inherit (builtins) listToAttrs;
      inherit (pkgs) mkShellWrapperNoCC;
      inherit (lib) nameValuePair pipe;

      partials = import ./partials.nix (moduleContext // perSystemContext);
      makeDevShellOutputs =
        shellSpecs:
        pipe shellSpecs [
          (map (spec: nameValuePair spec.name (mkShellWrapperNoCC spec)))
          listToAttrs
          (shells: shells // { default = shells.local; })
          (shells: { devShells = shells; })
        ];
    in
    makeDevShellOutputs [
      {
        name = "local";
        inputsFrom = with partials; [
          scriptInterpreter
          speakerctl
          gozip
          taskRunner
          gitHooks
          sync
          checks
          vsCode
        ];
      }

      {
        name = "ci-essentials";
        inputsFrom = with partials; [ ciEssentials ];
      }

      {
        name = "ci-check-pull-request";
        inputsFrom = with partials; [
          ciEssentials
          checks
        ];
      }

      {
        name = "ci-renovate";
        inputsFrom = with partials; [ ciEssentials ];
        packages = with pkgs; [ renovate ];
        shellHook = ''
          export RENOVATE_CONFIG_FILE="$PWD/.github/renovate-global.json5"
          export LOG_LEVEL='debug'
          # Post-Upgrade tasks are executed in the directory of the repo that's
          # currently being processed. I'm going to save the path to this repo so I
          # can run the scripts in it.
          export RENOVATE_BOT_REPO="$PWD"
        '';
      }
    ];
}
