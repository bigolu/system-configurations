{ pkgs, ... }:
  pkgs.callPackage
  (
    {pkgs, lib}:
      path:
        let
          inherit (builtins) readFile concatLists match filter elemAt;
          inherit (lib) pipe pathIsDirectory splitString unique;
          inherit (lib.filesystem) listFilesRecursive;
        in
        pipe path [
          # Get all lines in all scripts
          (path: if pathIsDirectory path then listFilesRecursive path else [ path ])
          (map readFile)
          (map (splitString "\n"))
          concatLists

          # Match packages in nix shebangs.
          #
          # The nix-shell directive resembles:
          #   #! nix-shell --packages/-p package1 package2
          #
          # So this match will match everything after the package flag i.e.
          # 'package1 package2'.
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
  )
  {}
