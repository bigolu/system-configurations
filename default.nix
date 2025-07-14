context@{ pkgs ? 4}:
  pkgs.lib.recursiveUpdate [
    (import ./nix/public context)
    (import ./nix/private)
    (import ./nix/dev/shells)
  ]
