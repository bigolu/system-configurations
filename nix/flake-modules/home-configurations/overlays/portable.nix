# This modules tries to keep the size of the portable shell down by removing large
# packages or using their minimal variant.
final: prev:
let
  inherit (builtins) listToAttrs;
  inherit (prev.lib) pipe nameValuePair;

  makeEmptyPackage =
    pkgs: packageName:
    pkgs.runCommand "${packageName}-empty" { meta.mainProgram = packageName; } ''mkdir -p $out/bin'';

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
        (map (packageName: nameValuePair packageName (makeEmptyPackage final packageName)))
        listToAttrs
      ];
in
emptyPackages
