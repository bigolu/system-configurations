# Remove large or unnecessary packages from the portable shell
{ packages, lib, ... }:
let
  inherit (builtins) listToAttrs;
  inherit (lib) pipe nameValuePair;

  makeEmptyPackage = packageName: packages.writeScriptBin packageName "";

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
]
