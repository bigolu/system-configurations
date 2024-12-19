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
        getExe
        ;
      inherit (pkgs) runCommand;

      prefixAttrNames = prefix: mapAttrs' (name: nameValuePair "${prefix}-${name}");

      bundlerChecks =
        let
          bundlerPrefix = "bundler";

          rootlessBundlerName = "rootless";
          rootlessBundler = self'.bundlers.${rootlessBundlerName};
          # TODO: To ensure the bundle isn't accessing the nix store I should use
          # something like chroot.
          rootlessBundlerCheck = runCommand "check-${bundlerPrefix}-${rootlessBundlerName}" { } ''
            [[ $(${rootlessBundler pkgs.hello}) == $(${getExe pkgs.hello}) ]]

            # runCommand only considers the command to be successful if something
            # is written to $out.
            echo success > $out
          '';
        in
        prefixAttrNames bundlerPrefix {
          ${rootlessBundlerName} = rootlessBundlerCheck;
        };
    in
    {
      checks = bundlerChecks;
    };
}
