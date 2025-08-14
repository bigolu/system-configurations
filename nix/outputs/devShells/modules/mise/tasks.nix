{
  pkgs,
  lib,
  utils,
  ...
}:
let
  inherit (lib)
    pipe
    unique
    concatMap
    fileset
    ;
  inherit (utils) projectRoot;
  inherit (pkgs) resolveNixShellShebang;
in
{
  devshell.packages = pipe (projectRoot + /mise/tasks) [
    (fileset.fileFilter (file: file.hasExt "bash"))
    fileset.toList
    (concatMap (script: (resolveNixShellShebang script).packages))
    unique
  ];
}
