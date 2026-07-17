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

  programs = {
    home-manager.enable = mkForce false;
    nix-index = {
      enable = false;
      symlinkToCacheHome = false;
    };
    # fishMinimal doesn't include Python which means the features listed here won't
    # work: https://github.com/NixOS/nixpkgs/pull/387070#issuecomment-2700435274
    fish.package = pkgs.fishMinimal;
  };

  home = {
    activation.reloadSystemd = mkForce (hm.dag.entryAnywhere "");
    file.".hammerspoon/Spoons/EmmyLua.spoon" = mkForce {
      source = pkgs.emptyFile;
      recursive = false;
    };
  };

  systemd.user = {
    # This removes the dependency on `sd-switch`.
    startServices = mkForce false;
    services = mkForce { };
    timers = mkForce { };
  };

  launchd.agents = mkForce { };
  xdg.mime.enable = mkForce false;
  # to remove the flake registry
  nix.enable = false;
}
