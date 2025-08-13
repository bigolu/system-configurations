{
  lib,
  inputs,
  pkgs,
  utils,
  pins,
  ...
}:
let
  projectRoot = ../..;

  homeManager = rec {
    moduleRoot = ./home-modules;
    # This is the module that I always include.
    commonModule = moduleRoot + "/common";

    makeConfiguration =
      {
        packageOverrides ? { },
        configName,
        modules,
        hasGui ? true,
        username ? "biggs",
        homePrefix ? if pkgs.stdenv.isLinux then "/home" else "/Users",
        homeDirectory ? "${homePrefix}/${username}",
        repositoryDirectory ? "${homeDirectory}/code/system-configurations",
      }:
      inputs.home-manager.outputs.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = modules ++ [
          commonModule
          { _module.args.pkgs = lib.mkForce (pkgs // packageOverrides); }
        ];

        # SYNC: SPECIAL-ARGS
        extraSpecialArgs = {
          inherit
            configName
            homeDirectory
            hasGui
            repositoryDirectory
            username
            inputs
            utils
            pins
            ;
        };
      };
  };

  # This is the version I give to packages that are only used inside of this project.
  # They don't actually have a version, but they need one for them to be displayed
  # properly by the nix. Nix considers everything up until the first dash not
  # followed by a letter to be the package name[1] so I'll start this version with a
  # number.
  #
  # [1]: https://nix.dev/manual/nix/2.30/language/builtins.html#builtins-parseDrvName
  unstableVersion = "0-unstable";

  applyIf =
    shouldApply: function: arg:
    if shouldApply then function arg else arg;

  gitFilter =
    let
      # For performance, this shouldn't be called often[1] so we'll save a reference.
      #
      # [1]: https://github.com/hercules-ci/gitignore.nix/blob/637db329424fd7e46cf4185293b9cc8c88c95394/docs/gitignoreFilter.md
      filter = inputs.gitignore.outputs.gitignoreFilterWith { basePath = projectRoot; };
    in
    src: lib.cleanSourceWith { inherit filter src; };
in
{
  inherit
    projectRoot
    homeManager
    unstableVersion
    applyIf
    gitFilter
    ;
}
