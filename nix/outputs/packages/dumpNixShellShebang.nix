{ nixpkgs, ... }:
nixpkgs.callPackage (
  { pkgs, lib }:
  path:
  let
    inherit (builtins)
      readFile
      concatLists
      match
      filter
      elemAt
      ;
    inherit (lib)
      pipe
      pathIsDirectory
      splitString
      unique
      hasPrefix
      ;
    inherit (lib.filesystem) listFilesRecursive;
  in
  pipe path [
    # Get all nix-shell directives in all scripts
    (path: if pathIsDirectory path then listFilesRecursive path else [ path ])
    (map readFile)
    (map (splitString "\n"))
    (map (filter (hasPrefix "#! nix-shell")))
    concatLists

    # Extract packages from nix-shell directives.
    #
    # A nix-shell directive that specifies packages will resemble:
    #   #! nix-shell --packages/-p package1 package2
    #
    # So this match will match everything after the package flag i.e.
    # 'package1 package2'.
    #
    # TODO: This doesn't handle expressions yet, only attribute names.
    (map (match ''^#! nix-shell (--packages|-p) (.*)''))
    (filter (matches: matches != null))
    (map (matches: elemAt matches 1))

    # Flatten the output of the previous match i.e. each string in the list will
    # hold _one_ package, instead of multiple separated by a space.
    (map (splitString " "))
    concatLists

    unique
    (map (packageName: pkgs.${packageName}))
  ]
) { }
