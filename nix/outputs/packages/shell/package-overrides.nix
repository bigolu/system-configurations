# Remove large or unnecessary packages from the portable shell
{ pkgs, lib, ... }:
let
  inherit (lib)
    optionals
    foldl'
    recursiveUpdate
    setAttrByPath
    ;
  inherit (pkgs) runCommand;
  inherit (pkgs.stdenv) isDarwin;

  emptyPackage =
    # `lib.getExe` will be called with these packages so `meta.mainProgram` must be
    # set.
    runCommand "empty-package" { meta.mainProgram = "program"; } ''
      # `pkgs.buildEnv` will be called with these packages and the path "/bin" so
      # "bin" needs to exist.
      mkdir --parents $out/bin
    '';

  recursiveUpdateList = foldl' recursiveUpdate { };

  makeEmptyPackageSet =
    packagePaths: recursiveUpdateList (map (path: setAttrByPath path emptyPackage) packagePaths);
in
{
  fish = pkgs.fishMinimal;
  git = pkgs.gitMinimal;
}
// (makeEmptyPackageSet (
  [
    [
      "lixPackageSet"
      "comma"
    ]
    [
      "lixPackageSet"
      "lix"
    ]
    [ "diffoscopeMinimal" ]
    [ "difftastic" ]
    [ "lesspipe" ]
    [ "ripgrep-all" ]
    [ "timg" ]
  ]
  ++ optionals isDarwin [
    [ "moreutils" ]
  ]
))
