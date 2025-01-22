{ lib, self, ... }:
let
  inherit (builtins) concatStringsSep attrNames;
  inherit (lib) hasPrefix;
in
{
  flake.expressions.systemConfigurationsAsMarkdown =
    let
      homeManagerConfigNames = builtins.filter (name: !hasPrefix "portable-home" name) (
        attrNames self.homeConfigurations
      );
      homeManagerPlatformFetcher = name: self.homeConfigurations.${name}.activationPackage.system;

      nixDarwinConfigNames = builtins.attrNames self.darwinConfigurations;
      nixDarwinPlatformFetcher = name: self.darwinConfigurations.${name}.system.system;

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

    '';
}
