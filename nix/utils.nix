inputs:
let
  inherit (inputs.nixpkgs) lib;
  inherit (lib) concatStringsSep recurseIntoAttrs;
  inherit (builtins) removeAttrs attrNames match;

  projectRoot = ../.;

  # YYYYMMDDHHMMSS -> YYYY-MM-DD
  formatDate =
    date:
    let
      yearMonthDayStrings = match "(....)(..)(..).*" date;
    in
    concatStringsSep "." yearMonthDayStrings;

  removeRecurseIntoAttrs = set: removeAttrs set (attrNames (recurseIntoAttrs { }));

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
