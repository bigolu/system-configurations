{
  pkgs,
  lib,
  name,
  inputs,
  pins,
  ...
}:
let
  inherit (lib) optionals hasPrefix optionalAttrs;
  inCi = hasPrefix "ci-" name;
in
{
  imports = optionals inCi [ ./ci ];

  devshell.bashPackage = pkgs.bashNonInteractive;
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

  devshell.startup.gcRoots.text =
    (pkgs.gcRoots {
      hook.directory = ".direnv/gc-roots";

      roots = {
        flake = { inherit inputs; };
      }
      // optionalAttrs (!inCi) {
        npins = { inherit pins; };
      };
    }).shellHook;
}
