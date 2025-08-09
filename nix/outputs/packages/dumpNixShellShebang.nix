{ nixpkgs, ... }:
nixpkgs.callPackage (
  { pkgs, lib }:
  path:
  let
    inherit (lib)
      pipe
      pathIsDirectory
      splitString
      unique
      hasPrefix
      readFile
      match
      filter
      elemAt
      concatMap
      ;
    inherit (lib.filesystem) listFilesRecursive;

    extractNixShellDirectives =
      file:
      pipe file [
        readFile
        (splitString "\n")
        (filter (hasPrefix "#! nix-shell"))
      ];

    # TODO: This doesn't handle expressions yet, only attribute names.
    extractPackages =
      nixShellDirective:
      pipe nixShellDirective [
        # A nix-shell directive that specifies packages will resemble:
        #   #! nix-shell --packages/-p package1 package2
        #
        # So this match will match everything after the package flag i.e.
        # 'package1 package2'.
        (match ''^#! nix-shell (--packages|-p) (.*)'')
        (matches: if matches != null then elemAt matches 1 else null)
        (packageString: if packageString != null then splitString " " packageString else [ ])
        unique
        (map (packageName: pkgs.${packageName}))
      ];
  in
  pipe path [
    (path: if pathIsDirectory path then listFilesRecursive path else [ path ])
    (concatMap extractNixShellDirectives)
    (concatMap extractPackages)
  ]
) { }
