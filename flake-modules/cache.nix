# This output makes it easy to build all the packages that I want to cache in my cloud-hosted Nix
# package cache. I build this package from CI and cache everything that gets added to the Nix store
# as a result of building it.
{ self, ... }:
{
  perSystem =
    {
      self',
      pkgs,
      lib,
      system,
      ...
    }:
    let
      inherit (lib.attrsets)
        optionalAttrs
        mapAttrs
        filterAttrs
        hasAttrByPath
        attrByPath
        getAttrFromPath
        ;

      homeManagerPackagesByName =
        let
          homeManagerConfigurationsByHostName = attrByPath [
            "homeConfigurations"
          ] { } self;

          homeManagerPackagesByHostName = mapAttrs (
            _hostName: output: output.activationPackage
          ) homeManagerConfigurationsByHostName;

          supportedHomeManagerPackagesByHostName = filterAttrs (
            _hostName: package: package.system == system
          ) homeManagerPackagesByHostName;
        in
        supportedHomeManagerPackagesByHostName;

      nixDarwinPackagesByName =
        let
          nixDarwinConfigurationsByHostName = attrByPath [
            "darwinConfigurations"
          ] { } self;

          nixDarwinPackagesByHostName = mapAttrs (
            _hostName: output: output.system
          ) nixDarwinConfigurationsByHostName;

          supportedNixDarwinPackagesByHostName = filterAttrs (
            _hostName: package: package.system == system
          ) nixDarwinPackagesByHostName;
        in
        supportedNixDarwinPackagesByHostName;

      devShellsByName = attrByPath [ "devShells" ] { } self';

      bootstrapPackagesByName =
        builtins.foldl'
          (
            acc: name:
            let
              outputPath = [
                "packages"
                name
              ];
            in
            acc
            // optionalAttrs (hasAttrByPath outputPath self') { "${name}" = getAttrFromPath outputPath self'; }
          )
          { }
          [
            "homeManager"
            "nixDarwin"
            "nix"
          ];

      scriptDependenciesByName = {
        deps = pkgs.script-dependencies;
      };

      packagesToCacheByName =
        homeManagerPackagesByName
        // nixDarwinPackagesByName
        // devShellsByName
        // bootstrapPackagesByName
        // scriptDependenciesByName;

      outputs = {
        packages.default = pkgs.linkFarm "packages-to-cache" packagesToCacheByName;
      };
    in
    outputs;
}
