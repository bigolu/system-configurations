# Remove large or unnecessary packages from the portable shell
{ pkgs, lib, ... }:
let
  inherit (lib) genAttrs optionals const;
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

  makeEmptyPackageSet = packageNames: genAttrs packageNames (const emptyPackage);
in
makeEmptyPackageSet (
  [
    "comma"
    "diffoscopeMinimal"
    "difftastic"
    "lesspipe"
    "nix"
    "ripgrep-all"
    "timg"
  ]
  ++ optionals isDarwin [
    # This is over 1GB
    "moreutils"
  ]
)
