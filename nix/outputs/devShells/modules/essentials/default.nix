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
  stdenv = pkgs.stdenvNoCC;
  imports = optionals inCi [ ./ci ];

  inherit
    (pkgs.gcRoots {
      hook.directory = ".direnv/gc-roots";

      roots = {
        flake = { inherit inputs; };
      }
      // optionalAttrs (!inCi) {
        npins = { inherit pins; };
      };
    })
    shellHook
    ;
}
