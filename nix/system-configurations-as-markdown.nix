let
  flake = import ./flake-compat.nix;
  inherit (flake.inputs.nixpkgs) lib;
  inherit (flake) outputs;
  inherit (builtins) concatStringsSep attrNames filter;
  inherit (lib) hasPrefix;

  homeManagerConfigNames = filter (name: !hasPrefix "portable-home" name) (
    attrNames outputs.homeConfigurations
  );

  nixDarwinConfigNames = attrNames outputs.darwinConfigurations;

  makeListItems =
    configNames:
    let
      makeListItem = name: "  - ${name}";
    in
    concatStringsSep "\n" (map makeListItem configNames);
in
''


  - home-manager

  ${makeListItems homeManagerConfigNames}

  - nix-darwin

  ${makeListItems nixDarwinConfigNames}

''
