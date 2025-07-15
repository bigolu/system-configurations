{ pkgs, ... }:
let
  inherit (builtins) mapAttrs elem;

  noDerivation = [ "nixpkgs" ];
  sources = import ../npins;
in
mapAttrs (name: source: if elem name noDerivation then source else source { inherit pkgs; }) sources
