# Remove large or unnecessary packages from the portable shell
{ pkgs, lib, ... }:
let
  inherit (lib) pipe nameValuePair listToAttrs;

  makeEmptyPackage = packageName: pkgs.writeScriptBin packageName "";

  makeEmptyPackageSet =
    packageNames:
    pipe packageNames [
      (map (packageName: nameValuePair packageName (makeEmptyPackage packageName)))
      listToAttrs
    ];
in
makeEmptyPackageSet [
  "comma"
  "timg"
  "ripgrep-all"
  "lesspipe"
  "diffoscopeMinimal"
  "difftastic"
  "nix"
  # This is large on macOS where perl is ~1 GB because of the Apple SDK
  "moreutils"
]
