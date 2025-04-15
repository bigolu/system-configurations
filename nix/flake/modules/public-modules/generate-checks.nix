{
  lib,
  self,
  ...
}:
{
  perSystem =
    {
      self',
      system,
      ...
    }:
    let
      inherit (builtins) getAttr removeAttrs;
      inherit (lib)
        mapAttrs
        mapAttrs'
        nameValuePair
        filterAttrs
        pipe
        mergeAttrsList
        ;

      removeDefaultOutput = set: removeAttrs set [ "default" ];

      prefixAttrNames = prefix: mapAttrs' (name: nameValuePair "${prefix}-${name}");

      filterPackagesForCurrentSystem = filterAttrs (_name: package: package.system == system);

      darwinChecks = pipe self.darwinConfigurations [
        (mapAttrs (_name: getAttr "system"))
        filterPackagesForCurrentSystem
        (prefixAttrNames "darwin")
      ];

      devShellChecks = pipe self'.devShells [
        removeDefaultOutput
        (prefixAttrNames "dev-shell")
      ];

      homeChecks = pipe self.homeConfigurations [
        (mapAttrs (_name: getAttr "activationPackage"))
        filterPackagesForCurrentSystem
        (prefixAttrNames "home")
      ];

      packageChecks = pipe self'.packages [
        removeDefaultOutput
        (prefixAttrNames "package")
      ];
    in
    {
      checks = mergeAttrsList [
        darwinChecks
        devShellChecks
        homeChecks
        packageChecks
      ];
    };
}
