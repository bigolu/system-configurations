{
  pkgs,
  lib,
  name,
  inputs,
  pins,
  system,
  ...
}:
let
  inherit (lib)
    optional
    hasPrefix
    optionalAttrs
    getExe'
    elem
    filterAttrs
    hasSuffix
    ;
  inherit (pkgs.stdenv) isLinux;

  inCi = hasPrefix "ci-" name;
  bashCompletionShare = "${pkgs.bash-completion}/share";
in
{
  imports = [
    ../mise/cli.nix
  ]
  ++ optional inCi ./ci;

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
    # TODO: Upstream
    interactive.autocomplete.text = ''
      export XDG_DATA_DIRS="${bashCompletionShare}''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
      source ${bashCompletionShare}/bash-completion/bash_completion
    '';

    startup = {
      gcRoot.text =
        (pkgs.gcRoot {
          script.rootPath.eval = "$DEV_SHELL_STATE/gc-roots/${name}";
          roots = {
            flake = {
              inherit inputs;
              exclude =
                # PERF: It pulls in another nixpkgs
                (optional inCi "nix-sweep")
                ++ (
                  if isLinux then
                    [
                      "nix-darwin"
                    ]
                  else
                    [
                      "nix-flatpak"
                      "nix-gl-host"
                    ]
                );
            };

            path = optionalAttrs (!inCi) (
              filterAttrs (
                name: pin:
                ((hasPrefix "config-file-validator-" name) -> (hasSuffix system name))
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
            );
          };
        }).script;

      # HACK: This should run before other startup scripts, but there's no way to
      # control the order. I noticed that they're sorted so I'm prefixing it with
      # 'AAA' in hopes that it gets put first.
      AAAstateDirectory.text =
        let
          inherit (pkgs) coreutils;
          mkdir = getExe' coreutils "mkdir";
        in
        ''
          export DEV_SHELL_STATE="''${DEV_SHELL_STATE:-''${PRJ_ROOT:?}/.dev-shell-state}"
          if [[ ! -e $DEV_SHELL_STATE ]]; then
            ${mkdir} --parents "$DEV_SHELL_STATE"
            echo '*' >"$DEV_SHELL_STATE/.gitignore"
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
    };
  };
}
