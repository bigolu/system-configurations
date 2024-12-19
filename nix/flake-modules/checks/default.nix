{
  lib,
  ...
}:
{
  perSystem =
    {
      self',
      pkgs,
      ...
    }:
    let
      inherit (lib)
        mapAttrs'
        nameValuePair
        ;

      prefixAttrNames = prefix: mapAttrs' (name: nameValuePair "${prefix}-${name}");

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
    in
    {
      checks = bundlerChecks;
    };
}
