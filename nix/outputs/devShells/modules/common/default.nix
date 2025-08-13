{
  pkgs,
  lib,
  name,
  utils,
  flakeInputs,
  ...
}:
let
  inherit (lib) optionals hasPrefix optionalAttrs;
  inherit (utils) projectRoot;
  inCi = hasPrefix "ci-" name;
in
{
  stdenv = pkgs.stdenvNoCC;
  imports = optionals inCi [ ./ci-essentials.nix ];

  inherit
    (pkgs.gcRoots {
      hook.destination = toString (projectRoot + /.direnv/gc-roots);

      roots = {
        flake.inputs = flakeInputs;
      }
      // optionalAttrs (!inCi) {
        npins.pins = import (projectRoot + /npins);
      };
    })
    shellHook
    ;
}
