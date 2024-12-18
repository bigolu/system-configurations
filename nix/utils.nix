inputs:
let
  inherit (inputs.nixpkgs) lib;
  inherit (builtins) removeAttrs attrNames;

  projectRoot = ../.;

  # YYYYMMDDHHMMSS -> YYYY-MM-DD
  formatDate =
    date:
    let
      yearMonthDayStrings = builtins.match "(....)(..)(..).*" date;
    in
    lib.concatStringsSep "-" yearMonthDayStrings;

  removeRecurseIntoAttrs = set: removeAttrs set (attrNames (lib.recurseIntoAttrs { }));

  homeManager =
    let
      moduleRoot = ./flake-modules/home-configurations/modules;
      # This is the module that I always include.
      baseModule = "${moduleRoot}/profile/base.nix";
    in
    {
      inherit moduleRoot baseModule;
    };
in
{
  inherit
    projectRoot
    formatDate
    removeRecurseIntoAttrs
    homeManager
    ;
}
