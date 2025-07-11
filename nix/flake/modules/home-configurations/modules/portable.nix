# This module tries to keep the size of the portable shell down by removing
# dependencies on large packages.
{ lib, pkgs, ... }:
let
  inherit (lib) mkForce optionalAttrs hm;
  inherit (pkgs.stdenv) isLinux;

  # These variables contain the path to the locale archive in
  # pkgs.glibcLocales. There is no option to prevent Home Manager from making
  # these environment variables and overriding glibcLocales in an overlay would
  # cause too many rebuild so instead I overwrite the environment variables.
  # Now glibcLocales won't be a dependency.
  emptySessionVariables = mkForce {
    LOCALE_ARCHIVE_2_27 = "";
    LOCALE_ARCHIVE_2_11 = "";
  };
in
{
  # I want a self contained executable so I can't have symlinks that point
  # outside the Nix store.
  repository.fileSettings.editableInstall = mkForce false;

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
    sessionVariables = optionalAttrs isLinux emptySessionVariables;

    file.".hammerspoon/Spoons/EmmyLua.spoon" = mkForce {
      source = pkgs.emptyFile;
      recursive = false;
    };

    # Since I'm running Home Manager in "submodule mode", I have to set these or
    # else it won't build.
    username = "biggs";
    homeDirectory = "/no/home/directory";

    activation.reloadSystemd = mkForce (hm.dag.entryAnywhere "");
  };

  systemd.user = {
    # This removes the dependency on `sd-switch`.
    startServices = mkForce "suggest";
    sessionVariables = optionalAttrs isLinux emptySessionVariables;
    services = mkForce { };
    timers = mkForce { };
  };

  launchd.agents = mkForce { };

  xdg = {
    mime.enable = mkForce false;
  };

  # to remove the flake registry
  nix.enable = false;
}
