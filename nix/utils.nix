{
  inputs,
  pkgs,
  ...
}:
let
  inherit (pkgs.lib)
    cleanSourceWith
    fileset
    isAttrs
    isPath
    id
    ;

  projectRoot = ../.;

  callIf = condition: function: if condition then function else id;

  gitFilter =
    let
      # For performance, this shouldn't be called often[1] so we'll save a reference.
      #
      # [1]: https://github.com/hercules-ci/gitignore.nix/blob/637db329424fd7e46cf4185293b9cc8c88c95394/docs/gitignoreFilter.md
      filter = inputs.gitignore.lib.gitignoreFilterWith { basePath = projectRoot; };
    in
    filesetOrPath:
    let
      clean = cleanSourceWith {
        inherit filter;
        src = callIf (isAttrs filesetOrPath) fileset.toSource filesetOrPath;
      };
      # Returning a fileset to allow for further filtering
      fs = fileset.fromSource clean;
    in
    fs
    // {
      outPath = fileset.toSource {
        root = if isPath filesetOrPath then filesetOrPath else projectRoot;
        fileset = fs;
      };
    };
in
{
  inherit
    projectRoot
    callIf
    gitFilter
    ;
}
