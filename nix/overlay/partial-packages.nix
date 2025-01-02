{ inputs, ... }:
final: _prev:
let
  inherit (inputs.nixpkgs) lib;
  inherit (final.stdenv) isLinux;
  inherit (lib) optionalAttrs concatStringsSep;

  filterPrograms =
    package: programsToKeep:
    let
      findFilters = map (program: "! -name '${program}'") programsToKeep;
      findFiltersAsString = concatStringsSep " " findFilters;
    in
    final.symlinkJoin {
      name = "${package.name}-partial";
      paths = [ package ];
      buildInputs = [ final.makeWrapper ];
      postBuild = ''
        cd $out/bin
        find . ${findFiltersAsString} -type f,l -exec rm -f {} +
      '';
    };

  xargs = filterPrograms final.findutils [ "xargs" ];
  ps = filterPrograms final.procps [ "ps" ];

  # The pstree from psmisc is preferred on linux for some reason:
  # https://github.com/NixOS/nixpkgs/blob/3dc440faeee9e889fe2d1b4d25ad0f430d449356/pkgs/applications/misc/pstree/default.nix#L36C8-L36C8
  pstree = filterPrograms final.psmisc [ "pstree" ];

  # toybox is a multi-call binary so we are going to delete everything besides the
  # toybox executable and the programs I need which are just symlinks to it.
  toybox = filterPrograms final.toybox [
    "toybox"
    "tar"
    "hostname"
  ];

  look = filterPrograms final.util-linux [ "look" ];
in
{
  partialPackages =
    final.lib.recurseIntoAttrs {
      inherit
        toybox
        xargs
        ps
        look
        ;
    }
    // optionalAttrs isLinux {
      inherit pstree;
    };
}
