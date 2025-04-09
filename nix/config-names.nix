let
  flake = import ./flake-compat.nix;
  inherit (flake.inputs.nixpkgs) lib;
  inherit (flake) outputs;
  inherit (builtins) attrNames filter concatStringsSep;
  inherit (lib) hasPrefix;

  homeManagerConfigNames = filter (name: !hasPrefix "portable-home" name) (
    attrNames outputs.homeConfigurations
  );

  nixDarwinConfigNames = attrNames outputs.darwinConfigurations;

  configNames = homeManagerConfigNames ++ nixDarwinConfigNames;
in
concatStringsSep "|" configNames
