{ lib, self, ... }:
{
  perSystem =
    {
      self',
      pkgs,
      system,
      ...
    }:
    let
      inherit (lib)
        mapAttrs
        mapAttrs'
        nameValuePair
        filterAttrs
        pipe
        ;

      removeDefaultOutput = set: builtins.removeAttrs set [ "default" ];

      prefixAttrNames = prefix: mapAttrs' (name: value: nameValuePair "${prefix}-${name}" value);

      filterPackagesForCurrentSystem = filterAttrs (_name: package: package.system == system);

      createBundlerCheck =
        name: bundler: pkgs.runCommand "bundler-check-${name}" { } "${bundler pkgs.hello} > $out ";

      bundlerChecks = pipe self'.bundlers [
        removeDefaultOutput
        (mapAttrs createBundlerCheck)
        (prefixAttrNames "bundler")
      ];

      darwinChecks = pipe self.darwinConfigurations [
        (mapAttrs (_name: config: config.system))
        filterPackagesForCurrentSystem
        (prefixAttrNames "darwin")
      ];

      devShellChecks = pipe self'.devShells [
        removeDefaultOutput
        (prefixAttrNames "dev-shell")
      ];

      homeChecks = pipe self.homeConfigurations [
        (mapAttrs (_name: config: config.activationPackage))
        filterPackagesForCurrentSystem
        (prefixAttrNames "home")
      ];

      packageChecks = pipe self'.packages [
        removeDefaultOutput
        (prefixAttrNames "package")
      ];
    in
    {
      checks = lib.foldl (accumulator: next: accumulator // next) { } [
        bundlerChecks
        darwinChecks
        devShellChecks
        homeChecks
        packageChecks
      ];
    };
}
