{
  pkgs,
  lib,
  name,
  inputs,
  pins,
  ...
}:
let
  inherit (lib)
    optionals
    hasPrefix
    optionalAttrs
    getExe'
    ;
  inCi = hasPrefix "ci-" name;
in
{
  imports = [
    ../mise/cli.nix
  ]
  ++ optionals inCi [
    ./ci
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

  devshell.startup = {
    gcRoots.text =
      (pkgs.gcRoots {
        snippet.directory.eval = "$DEV_SHELL_STATE/gc-roots";
        roots = {
          flake = { inherit inputs; };
          namedGroup = optionalAttrs (!inCi) { inherit pins; };
        };
      }).snippet;

    # HACK: This should run before other startup snippets, but there's no way to
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
      if [[ -e ''${PRJ_ROOT:?}/.env ]]; then
        # Export any variables that are modified/created
        set -a
        source ''${PRJ_ROOT:?}/.env
        set +a
      fi
    '';
  };
}
