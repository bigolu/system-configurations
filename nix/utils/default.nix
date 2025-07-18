{
  lib,
  pins,
  packages,
  utils,
  ...
}:
let
  inherit (lib) concatStringsSep;
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

  homeManager = rec {
    moduleRoot = ./home-modules;
    # This is the module that I always include.
    commonModule = "${moduleRoot}/common";

    makeConfiguration =
      {
        packageOverrides ? { },
        configName,
        modules,
        isGui ? true,
        username ? "biggs",
        isHomeManagerRunningAsASubmodule ? false,
        homePrefix ? if packages.stdenv.isLinux then "/home" else "/Users",
        homeDirectory ? "${homePrefix}/${username}",
        repositoryDirectory ? "${homeDirectory}/code/system-configurations",
      }:
      pins.home-manager.outputs.lib.homeManagerConfiguration {
        pkgs = packages;
        modules = modules ++ [
          commonModule
          { _module.args.pkgs = lib.mkForce (packages // packageOverrides); }
        ];

        # SYNC: SPECIAL-ARGS
        extraSpecialArgs = {
          inherit
            configName
            homeDirectory
            isGui
            isHomeManagerRunningAsASubmodule
            repositoryDirectory
            username
            pins
            utils
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

  gitFilter =
    let
      # For performance, this shouldn't be called often[1] so we'll save a reference.
      #
      # [1]: https://github.com/hercules-ci/gitignore.nix/blob/637db329424fd7e46cf4185293b9cc8c88c95394/docs/gitignoreFilter.md
      filter = pins.gitignore.outputs.gitignoreFilterWith { basePath = projectRoot; };
    in
    src: lib.cleanSourceWith { inherit filter src; };
in
{
  inherit
    projectRoot
    formatDate
    homeManager
    unstableVersion
    applyIf
    gitFilter
    ;
}
