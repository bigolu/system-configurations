let
  flake = import ./flake-compat.nix;
  inherit (flake.inputs.nixpkgs) lib;
  inherit (flake) outputs;
  inherit (builtins) concatStringsSep attrNames filter;
  inherit (lib) hasPrefix;

  homeManagerConfigNames = filter (name: !hasPrefix "portable-home" name) (
    attrNames outputs.homeConfigurations
  );
  homeManagerPlatformFetcher = name: outputs.homeConfigurations.${name}.activationPackage.system;

  nixDarwinConfigNames = attrNames outputs.darwinConfigurations;
  nixDarwinPlatformFetcher = name: outputs.darwinConfigurations.${name}.system.system;

  makeListItems =
    platformFetcher: configNames:
    let
      makeListItem = name: "  - ${name} / ${platformFetcher name}";
    in
    concatStringsSep "\n" (map makeListItem configNames);
in
''


  - Home Manager

  ${makeListItems homeManagerPlatformFetcher homeManagerConfigNames}

  - nix-darwin

  ${makeListItems nixDarwinPlatformFetcher nixDarwinConfigNames}

''
