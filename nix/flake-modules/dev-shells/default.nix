moduleContext@{ lib, ... }:
{
  perSystem =
    perSystemContext@{ pkgs, ... }:
    let
      inherit (builtins) mapAttrs;
      inherit (pkgs) mkShellWrapperNoCC;
      inherit (lib)
        pipe
        hasPrefix
        optionalAttrs
        ;

      partials = import ./partials.nix (moduleContext // perSystemContext);

      makeShell =
        spec@{
          inputsFrom ? [ ],
          name,
          ...
        }:
        let
          ciEssentials = with partials; [
            ciSetup
            scriptInterpreter
          ];
        in
        mkShellWrapperNoCC (
          spec
          // optionalAttrs (hasPrefix "ci-" name) {
            inputsFrom = inputsFrom ++ ciEssentials;
          }
        );

      makeDevShellOutputs =
        shellSpecs:
        pipe shellSpecs [
          (mapAttrs (name: spec: makeShell (spec // { inherit name; })))
          (shells: shells // { default = shells.local; })
          (shells: { devShells = shells; })
        ];
    in
    makeDevShellOutputs {
      local = {
        inputsFrom = with partials; [
          scriptInterpreter
          speakerctl
          gozip
          taskRunner
          gitHooks
          sync
          scriptDependencies
          checks
          vsCode
        ];
      };

      ci-essentials = { };

      ci-check-pull-request = {
        inputsFrom = with partials; [ checks ];
      };

      ci-renovate = {
        packages = with pkgs; [ renovate ];
        shellHook = ''
          export RENOVATE_CONFIG_FILE="$PWD/.github/renovate-global.json5"
          export LOG_LEVEL='debug'
          # Post-Upgrade tasks are executed in the directory of the repo that's
          # currently being processed. I'm going to save the path to this repo so I
          # can run the scripts in it.
          export RENOVATE_BOT_REPO="$PWD"
        '';
      };
    };
}
