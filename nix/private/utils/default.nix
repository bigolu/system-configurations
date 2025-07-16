{ lib, pins, private, utils, ... }:
let
  inherit (lib)
    concatStringsSep
    toLower
    pipe
    replaceString
    ;
  inherit (builtins)
    match
    ;
  inherit (private) pkgs;

  projectRoot = ../../..;

  # YYYYMMDDHHMMSS -> YYYY-MM-DD
  formatDate =
    date:
    let
      yearMonthDayStrings = match "(....)(..)(..).*" date;
    in
    concatStringsSep "." yearMonthDayStrings;

  homeManager = rec {
    moduleRoot = ./home-modules;
    # This is the module that I always include.
    commonModule = "${moduleRoot}/common";

    makeConfiguration =
      {
        overlay ? null,
        configName,
        modules,
        isGui ? true,
        username ? "biggs",
        isHomeManagerRunningAsASubmodule ? false,
        homePrefix ? if pkgs.stdenv.isLinux then "/home" else "/Users",
        homeDirectory ? "${homePrefix}/${username}",
        repositoryDirectory ? "${homeDirectory}/code/system-configurations",
      }:
      pins.home-manager.outputs.lib.homeManagerConfiguration {
        modules = modules ++ [ commonModule ];
        pkgs = if overlay == null then pkgs else pkgs.extend overlay;

        # SYNC: SPECIAL-ARGS
        extraSpecialArgs = {
          utils = utils // private.utils;
          inherit
            configName
            homeDirectory
            isGui
            isHomeManagerRunningAsASubmodule
            repositoryDirectory
            username
            pins
            ;
        };
      };
  };

  # This is the version I give to packages that are only used inside of this flake.
  # They don't actually have a version, but they need one for them to be displayed
  # properly by the nix CLI.
  #
  # Per nixpkgs' version conventions, it needs to start with a digit:
  # https://github.com/NixOS/nixpkgs/blob/master/pkgs/README.md#versioning
  unstableVersion = "0-unstable";

  applyIf =
    shouldApply: function: arg:
    if shouldApply then function arg else arg;
in
{
  inherit
    projectRoot
    formatDate
    homeManager
    unstableVersion
    applyIf
    ;
}
