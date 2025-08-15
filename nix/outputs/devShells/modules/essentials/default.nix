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
  imports = optionals inCi [ ./ci ];

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
        hook.directory.eval = "$DEV_SHELL_STATE/gc-roots";

        roots = {
          flake = { inherit inputs; };
        }
        // optionalAttrs (!inCi) {
          npins = { inherit pins; };
        };
      }).shellHook;

    # HACK: This should run before other startup snippets, but there's no way to
    # control the order. I noticed that they're sorted so I'm prefixing it with
    # 'AAA' in hopes that it gets put first.
    AAAstateDirectory.text =
      let
        inherit (pkgs) coreutils;
        mkdir = getExe' coreutils "mkdir";
      in
      ''
        dev_shell_dir="''${PRJ_ROOT:?}/.dev-shell"
        export DEV_SHELL_STATE="''${DEV_SHELL_STATE:-$dev_shell_dir/state}"
        if [[ ! -e $DEV_SHELL_STATE ]]; then
          ${mkdir} --parents "$DEV_SHELL_STATE"
          echo '*' >"$dev_shell_dir/.gitignore"
        fi
      '';

    secrets.text = ''
      if [[ -e secrets.env ]]; then
        # Export any variables that are modified/created
        set -a
        source secrets.env
        set +a
      fi
    '';
  };
}
