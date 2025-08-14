{
  pkgs,
  lib,
  name,
  inputs,
  pins,
  self,
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
    { name = "DEVSHELL_NO_MOTD"; value = 1; }
    { name = "NIXPKGS_PATH"; unset = true; }
  ];

  devshell.startup.gcRoots.text =
    (pkgs.gcRoots {
      hook.directory = ".direnv/gc-roots";
      hook.devShellDiff = true;

      roots = {
        flake = { inherit inputs; };
        devShell = self;
      }
      // optionalAttrs (!inCi) {
        npins = { inherit pins; };
      };
    }).shellHook;
}
