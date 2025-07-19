# We reduce the size of the portable shell by removing large packages.
{ packages, lib, ... }:
let
  inherit (builtins) listToAttrs;
  inherit (lib) pipe nameValuePair;

  makeEmptyPackage =
    packageName:
    packages.runCommand "${packageName}-empty" {
      meta.mainProgram = packageName;
    } ''mkdir -p $out/bin'';

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
