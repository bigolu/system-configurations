{
  lib,
  self,
  utils,
  ...
}:
{
  perSystem =
    {
      self',
      pkgs,
      system,
      ...
    }:
    let
      inherit (builtins) getAttr;
      inherit (lib)
        mapAttrs
        mapAttrs'
        nameValuePair
        filterAttrs
        pipe
        ;

      removeDefaultOutput = set: builtins.removeAttrs set [ "default" ];

      prefixAttrNames = prefix: mapAttrs' (name: nameValuePair "${prefix}-${name}");

      filterPackagesForCurrentSystem = filterAttrs (_name: package: package.system == system);

      bundlerChecks =
        let
          bundlerPrefix = "bundler";

          rootlessBundlerName = "rootless";
          rootlessBundler = self'.bundlers.${rootlessBundlerName};
          rootlessBundlerCheck =
            pkgs.runCommand "check-${bundlerPrefix}-${rootlessBundlerName}" { }
              "${rootlessBundler pkgs.hello} > $out ";
        in
        prefixAttrNames bundlerPrefix {
          ${rootlessBundlerName} = rootlessBundlerCheck;
        };

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
      checks = utils.mergeAttrsList [
        bundlerChecks
        darwinChecks
        devShellChecks
        homeChecks
        packageChecks
      ];
    };
}
