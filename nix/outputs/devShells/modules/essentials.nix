{
  pkgs,
  lib,
  inputs,
  pins,
  system,
  config,
  extraModulesPath,
  ...
}:
let
  inherit (lib)
    optional
    hasPrefix
    optionals
    getExe'
    elem
    filterAttrs
    hasSuffix
    attrValues
    ;
  inherit (pkgs.stdenv) isLinux;

  inherit (config.devshell) name;
  isCiDevShell = hasPrefix "ci-" name;
  bashCompletionShare = "${pkgs.bash-completion}/share";
  mkdir = getExe' pkgs.coreutils "mkdir";
in
{
  imports = [
    "${extraModulesPath}/locale.nix"
    ./mise/cli.nix
  ];

  env = [
    {
      name = "DEVSHELL_NO_MOTD";
      value = 1;
    }
    {
      name = "NIXPKGS_PATH";
      unset = true;
    }
  ];

  devshell = {
    # For the `run` steps in CI workflows
    packages = optional isCiDevShell pkgs.bash-script;

    interactive.autocomplete.text = ''
      export XDG_DATA_DIRS="${bashCompletionShare}''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
      source ${bashCompletionShare}/bash-completion/bash_completion
    '';

    startup = {
      # HACK: This should run before other startup scripts, but there's no way to
      # control the order. I noticed that they're sorted so I'm prefixing it with
      # 'AAA' in hopes that it gets put first.
      AAAstateDirectory.text = ''
        if [[ ! -e $PRJ_DATA_DIR ]]; then
          ${mkdir} --parents "$PRJ_DATA_DIR"
          echo '*' >"$PRJ_DATA_DIR/.gitignore"
        fi
      '';

      secrets.text = ''
        if [[ -e $PRJ_ROOT/.env ]]; then
          # Export any variables that are modified/created
          set -a
          source "$PRJ_ROOT/.env"
          set +a
        fi
      '';

      gcRoot.text =
        (pkgs.gcRoot {
          script.rootPath.eval = "$PRJ_DATA_DIR/gc-roots/${name}";
          roots = {
            flake = {
              inherit inputs;
              exclude =
                # PERF: It pulls in another nixpkgs
                (optional isCiDevShell "nix-sweep")
                ++ (
                  if isLinux then
                    [
                      "nix-darwin"
                    ]
                  else
                    [
                      "nix-gl-host"
                    ]
                );
            };

            paths = optionals (!isCiDevShell) (
              attrValues (
                filterAttrs (
                  name: pin:
                  (name != "__functor")
                  && ((hasPrefix "config-file-validator-" name) -> (hasSuffix system name))
                  && (
                    !(elem pin (
                      with pins;
                      if isLinux then
                        [
                          spoons
                          stackline
                        ]
                      else
                        [
                          keyd
                        ]
                    ))
                  )
                ) pins
              )
            );
          };
        }).script;
    };
  };
}
