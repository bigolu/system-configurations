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
        ;

      partials = import ./partials.nix (moduleContext // perSystemContext);

      applyIf =
        condition: function: arg:
        if condition then function arg else arg;

      includeCiEssentials =
        devShellSpec:
        let
          ciEssentials = with partials; [
            ciSetup
            scriptInterpreter
          ];
        in
        devShellSpec // { inputsFrom = (devShellSpec.inputsFrom or [ ]) ++ ciEssentials; };

      makeDevShellOutputs =
        devShellSpecs:
        pipe devShellSpecs [
          (mapAttrs (name: spec: spec // { inherit name; }))
          (mapAttrs (name: applyIf (hasPrefix "ci-" name) includeCiEssentials))
          (mapAttrs (_name: mkShellWrapperNoCC))
          (devShells: { inherit devShells; })
        ];
    in
    makeDevShellOutputs rec {
      default = local;

      local = {
        inputsFrom = with partials; [
          scriptInterpreter
          speakerctl
          gozip
          taskRunner
          lefthook
          sync
          scriptDependencies
          luaLs
          checks
          vsCode
        ];
      };

      ci-essentials = { };

      ci-check-pull-request = {
        inputsFrom = with partials; [
          checks
          # This is needed for generating task documentation
          taskRunner
          # This is needed for running mypy
          speakerctl
          # Runs the checks
          lefthook
          # This is needed for running lua-language-server
          luaLs
          gozip
        ];
      };

      ci-check-for-broken-links = {
        inputsFrom = with partials; [
          # Runs the check
          lefthook
        ];
        shellHook = ''
          export ENABLE_LYCHEE='true'
        '';
      };

      ci-renovate = {
        packages = with pkgs; [ renovate ];
        shellHook = ''
          export RENOVATE_CONFIG_FILE="$PWD/renovate/global/config.json5"
          export LOG_LEVEL='debug'
          # Post-Upgrade tasks are executed in the directory of the repo that's
          # currently being processed. I'm going to save the path to this repo so I
          # can run the scripts in it.
          export RENOVATE_BOT_REPO="$PWD"
        '';
      };
    };
}
