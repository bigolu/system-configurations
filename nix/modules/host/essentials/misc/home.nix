{
  lib,
  inputs,
  config,
  myUtils,
  ...
}:
let
  inherit (builtins) storeDir;
  inherit (lib)
    optionalAttrs
    inPureEvalMode
    isPath
    cleanSourceWith
    hasPrefix
    ;
  inherit (myUtils) projectRoot programConfigRoot callIf;

  gitignoreFilter =
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
  home.stateVersion = "23.11";

  fileWrapper.settings = {
    editableInstall = true;

    relativePathRoot = {
      access = programConfigRoot;
    }
    // optionalAttrs inPureEvalMode {
      symlink = "${config.home.homeDirectory}/code/system-configurations/program-configs";
    };

    # Flakes have built-in gitignore support
    directoryFilter = callIf (!inPureEvalMode) gitignoreFilter;
  };
}
