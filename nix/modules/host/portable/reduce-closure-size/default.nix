pkgs':
{ lib, pkgs, ... }:
let
  inherit (lib) mkForce hm recursiveUpdate;
in
{
  # We don't use the `pkgs` module argument to avoid infinite recursion.
  _module.args.pkgs = mkForce (recursiveUpdate pkgs' (import ./package-overrides.nix pkgs'));

  # This contains only the "en_US.UTF-8/UTF-8" locale.
  i18n.glibcLocales = pkgs.glibcLocalesUtf8;

  # fishMinimal doesn't include Python which means the features listed here won't
  # work: https://github.com/NixOS/nixpkgs/pull/387070#issuecomment-2700435274
  programs.fish.package = pkgs.fishMinimal;

  home.activation.reloadSystemd = mkForce (hm.dag.entryAnywhere "");

  # This removes the dependency on `sd-switch`.
  systemd.user.startServices = mkForce false;

  xdg.mime.enable = mkForce false;

  # to remove the flake registry
  nix.enable = false;
}
