{ pkgs, ... }:
let
  inherit (builtins) mapAttrs;
  pins = import ../npins;
in
mapAttrs
  # Use nixpkgs's derivation-based fetchers for all pins except nixpkgs channels.
  (name: pin: if pin.type == "Channel" then pin else pin { inherit pkgs; })
  pins
