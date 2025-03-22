# This overlay tries to keep the size of the portable shell down by removing large
# packages.
final: prev:
let
  inherit (builtins) listToAttrs;
  inherit (prev.lib) pipe nameValuePair;

  makeEmptyPackage =
    packageName:
    final.runCommand "${packageName}-empty" { meta.mainProgram = packageName; } ''mkdir -p $out/bin'';

  emptyPackages =
    pipe
      [
        "comma"
        "moreutils"
        "timg"
        "ripgrep-all"
        "lesspipe"
        "diffoscopeMinimal"
        "difftastic"
        "nix"
      ]
      [
        (map (packageName: nameValuePair packageName (makeEmptyPackage packageName)))
        listToAttrs
      ];
in
emptyPackages
