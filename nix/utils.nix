inputs:
let
  inherit (inputs.nixpkgs) lib;
  inherit (lib)
    concatStringsSep
    recurseIntoAttrs
    toLower
    pipe
    ;
  inherit (builtins)
    removeAttrs
    attrNames
    match
    replaceStrings
    ;

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

  # https://github.com/NixOS/nixpkgs/blob/master/pkgs/README.md#package-naming
  # This doesn't apply all of the conventions, but it's enough for now.
  toNixpkgsAttr =
    name:
    pipe name [
      (replaceStrings [ "." ] [ "-" ])
      toLower
    ];

  # https://github.com/NixOS/nixpkgs/blob/master/pkgs/README.md#package-naming
  toNixpkgsPname = toLower;
in
{
  inherit
    projectRoot
    formatDate
    removeRecurseIntoAttrs
    homeManager
    toNixpkgsAttr
    toNixpkgsPname
    ;
}
