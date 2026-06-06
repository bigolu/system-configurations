{ pkgs, ... }:
let
  inherit (pkgs.lib) id;
in
{
  projectRoot = ../.;
  callIf = condition: function: if condition then function else id;
}
