{ lib, ... }:
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

  projectRoot = ../..;

  # YYYYMMDDHHMMSS -> YYYY-MM-DD
  formatDate =
    date:
    let
      yearMonthDayStrings = match "(....)(..)(..).*" date;
    in
    concatStringsSep "." yearMonthDayStrings;

  homeManager =
    let
      moduleRoot = ./flake/modules/home-configurations/modules;
      # This is the module that I always include.
      commonModule = "${moduleRoot}/common";
    in
    {
      inherit moduleRoot commonModule;
    };

  # https://github.com/NixOS/nixpkgs/blob/master/pkgs/README.md#package-naming
  # This doesn't apply all of the conventions, but it's enough for my use case.
  toNixpkgsAttr =
    name:
    pipe name [
      (replaceString "." "-")
      toLower
    ];

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
    toNixpkgsAttr
    unstableVersion
    applyIf
    ;
}
