{ hasGui, hostName }:
{
  pkgs,
  lib,
  inputs,
  config,
  utils,
  ...
}:
let
  nixRoot = ../../../..;

  inherit (builtins) storeDir;
  inherit (lib)
    optionalAttrs
    inPureEvalMode
    isPath
    cleanSourceWith
    hasPrefix
    ;
  inherit (utils) projectRoot programConfigRoot callIf;

  directoryFilter =
    let
      # PERF: As per the documentation[1], we memoize this.
      #
      # [1]: https://github.com/hercules-ci/gitignore.nix/blob/637db329424fd7e46cf4185293b9cc8c88c95394/docs/gitignoreFilter.md
      filter = inputs.gitignore.lib.gitignoreFilterWith { basePath = projectRoot; };
    in
    stringOrPath:
    cleanSourceWith {
      inherit filter;
      # Clean source won't accept a string
      src =
        if (isPath stringOrPath || hasPrefix storeDir stringOrPath) then
          stringOrPath
        else
          /. + stringOrPath;
    };
in
{
  _module.args = {
    inherit hasGui hostName;
    utils = import (nixRoot + /utils.nix);
    pins = import (nixRoot + /pins) pkgs;
  };

  fileWrapper.settings = {
    editableInstall = true;

    relativePathRoot = {
      access = programConfigRoot;
    }
    // optionalAttrs inPureEvalMode {
      symlink = "${config.home.homeDirectory}/code/system-configurations/program-configs";
    };

    # Flakes have built-in gitignore support
    directoryFilter = callIf (!inPureEvalMode) directoryFilter;
  };
}
