# We reduce the size of the portable shell by removing large packages.
{ pkgs, lib, ... }:
let
  inherit (builtins) listToAttrs;
  inherit (lib) pipe nameValuePair;

  makeEmptyPackage =
    packageName:
    pkgs.runCommand "${packageName}-empty" { meta.mainProgram = packageName; } ''mkdir -p $out/bin'';

  makeEmptyPackageSet =
    packageNames:
    pipe packageNames [
      (map (packageName: nameValuePair packageName (makeEmptyPackage packageName)))
      listToAttrs
    ];
in
makeEmptyPackageSet [
  "comma"
  "moreutils"
  "timg"
  "ripgrep-all"
  "lesspipe"
  "diffoscopeMinimal"
  "difftastic"
  "nix"
]
