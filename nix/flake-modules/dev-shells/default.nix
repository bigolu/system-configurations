moduleContext: {
  perSystem =
    perSystemContext@{
      pkgs,
      self',
      ...
    }:
    let
      inherit (pkgs) mkShellUniqueNoCC;
      partials = import ./partials.nix (moduleContext // perSystemContext);
    in
    {
      devShells = {
        default = self'.devShells.local;

        local = mkShellUniqueNoCC {
          name = "local";
          inputsFrom = with partials; [
            essentials
            plugctl
            linting
            formatting
            codeGeneration
            vsCode
            taskRunner
            versionControl
            languages
            sync
            scriptDependencies
          ];
        };

        ci-essentials = mkShellUniqueNoCC {
          name = "ci-essentials";
          inputsFrom = with partials; [ ciEssentials ];
        };

        ci-check-pull-request = mkShellUniqueNoCC {
          name = "ci-check-pull-request";
          inputsFrom = with partials; [
            ciEssentials
            linting
            formatting
            codeGeneration
          ];
        };

        ci-renovate = mkShellUniqueNoCC {
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
        };
      };
    };
}
