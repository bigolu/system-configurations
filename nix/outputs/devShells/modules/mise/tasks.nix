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
  inherit (pkgs) parseNixShebang;
in
{
  devshell.packages = pipe (projectRoot + /mise/tasks) [
    (fileset.fileFilter (file: file.hasExt "bash"))
    fileset.toList
    (concatMap (script: (parseNixShebang script).packages))
    unique
  ];
}
